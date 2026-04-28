from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from fastapi.staticfiles import StaticFiles
from typing import List, Dict, Any
import json
import base64
import fitz
from docx import Document
import openpyxl
import io
from dotenv import load_dotenv
import os
import mysql.connector
from groq import Groq

class ChatCreate(BaseModel):
    usuario_id: int
    chat_id: str
    titulo: str
    fecha: str
    mensajes: List[Dict[str, Any]]

class TicketIncidencia(BaseModel):
    usuario: str
    problema: str
    urgencia: str
    email: str
    departamento: str = "Informatica"

SYSTEM_PROMPT = """Eres DigiHelp, asistente de soporte técnico IT. Tu única función es resolver problemas técnicos.

INSTRUCCIÓN PRINCIPAL: SIEMPRE saluda al principio y haz nada mas que un saludo. Luego responde directamente al problema.

EJEMPLOS DE CÓMO DEBES RESPONDER:

Usuario: "la impresora no me va"
TÚ: "No te preocupes, vamos a arreglarlo juntos. Sigue estos pasos:
1. Apaga la impresora — busca el botón de encendido y mantenlo pulsado hasta que se apague.
2. Desenchufa el cable de la luz — el que va a la pared.
3. Espera 30 segundos.
4. Vuelve a enchufarlo y enciende la impresora.
¿Ha vuelto a funcionar?"

REGLAS:
- En la primera conversacion empieza con un saludo (¡Hola!, ¡Buenos días!, etc.).
- Responde directamente al problema sin rodeos.
- Si hay una imagen analízala describiendo qué ves.
- Si la pregunta no es de IT responde: "Solo puedo ayudarte con problemas técnicos. ¿Tienes alguna incidencia IT?"
- Usa lenguaje muy simple y pasos cortos (máximo 2 líneas).
- Siempre pregunta al final si ha funcionado."""

load_dotenv()
app = FastAPI(title="DigiHelp API - Backend")

app.mount("/videos", StaticFiles(directory="C:/Users/elmen/Desktop/Proyecto-Final/DigiHelp_PC/videos"), name="videos")

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def get_db_connection():
    try:
        return mysql.connector.connect(
            host=os.getenv("DB_HOST"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME")
        )
    except Exception as e:
        print(f"Error de base de datos: {e}")
        return None

class LoginData(BaseModel):
    username: str
    password: str

@app.post("/login")
def login_usuario(datos: LoginData):
    db = get_db_connection()
    if not db: raise HTTPException(status_code=500, detail="No hay conexión a la BD")
    cursor = db.cursor(dictionary=True)
    query = "SELECT id, username, nombre_completo, departamento, email FROM usuarios WHERE username = %s AND contrasenia = %s"
    cursor.execute(query, (datos.username, datos.password))
    usuario = cursor.fetchone()
    cursor.close()
    db.close()
    if usuario: return {"status": "ok", "usuario": usuario}
    else: raise HTTPException(status_code=401, detail="Usuario o contraseña incorrectos")

@app.post("/chat_multimodal")
async def chat_multimodal(
    mensaje: str = Form(...), 
    historial: str = Form("[]"),  
    archivo: UploadFile = File(None)
):
    try:
        # 👉 1. INTERCEPTAMOS PALABRAS CLAVE EN TU TABLA 'videos'
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT palabra_clave, mensaje, ruta_video FROM videos")
            respuestas_db = cursor.fetchall()
            cursor.close()
            conn.close()
            
            mensaje_lower = mensaje.lower()
            for fila in respuestas_db:
                if fila['palabra_clave'].lower() in mensaje_lower:
                    # ¡HAY COINCIDENCIA! Cortamos a la IA y devolvemos tu base de datos
                    return {
                        "status": "ok", 
                        "respuesta": fila['mensaje'],    # Usamos tu columna 'mensaje'
                        "ruta_video": fila['ruta_video'] # Usamos tu columna 'ruta_video'
                    }

        # 2. SI NO HAY PALABRA CLAVE, PROCESO NORMAL DE IA
        texto_extraido = ""
        es_imagen = False
        base64_image = ""
        
        if archivo:
            contenido = await archivo.read()
            ext = archivo.filename.split('.')[-1].lower()
            if ext in ['png', 'jpg', 'jpeg']:
                es_imagen = True
                base64_image = base64.b64encode(contenido).decode('utf-8')
            elif ext == 'pdf':
                doc = fitz.open(stream=contenido, filetype="pdf")
                for page in doc: texto_extraido += page.get_text() + "\n"
            elif ext == 'docx':
                doc = Document(io.BytesIO(contenido))
                for p in doc.paragraphs: texto_extraido += p.text + "\n"
            elif ext == 'xlsx':
                wb = openpyxl.load_workbook(io.BytesIO(contenido))
                for sheet in wb.worksheets:
                    for row in sheet.iter_rows(values_only=True):
                        texto_extraido += " ".join([str(c) for c in row if c is not None]) + "\n"

        mensajes_groq = [{"role": "system", "content": SYSTEM_PROMPT}]
        historial_lista = json.loads(historial)
        
        for msg in historial_lista[:-1]: 
            role = "assistant" if msg["rol"] in ["assistant", "model"] else "user"
            mensajes_groq.append({"role": role, "content": msg["texto"]})

        if es_imagen:
            mensajes_groq.append({
                "role": "user", 
                "content": [
                    {"type": "text", "text": mensaje},
                    {"type": "image_url", "image_url": {"url": f"data:image/{ext};base64,{base64_image}"}}
                ]
            })
            chat_completion = groq_client.chat.completions.create(
                messages=mensajes_groq,
                model="llama-3.2-90b-vision-preview",
                temperature=0.6,
                max_tokens=1024,
            )
        else:
            prompt_final = mensaje
            if texto_extraido: prompt_final += f"\n\n--- DOC ADJUNTO ---\n{texto_extraido}"
            mensajes_groq.append({"role": "user", "content": prompt_final})
            chat_completion = groq_client.chat.completions.create(
                messages=mensajes_groq,
                model="llama-3.3-70b-versatile",
                temperature=0.6,
                max_tokens=1024,
            )
            
        respuesta_ia = chat_completion.choices[0].message.content
        return {"status": "ok", "respuesta": respuesta_ia}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/guardar_chat")
async def guardar_chat(chat: ChatCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        mensajes_json = json.dumps(chat.mensajes, ensure_ascii=False)
        cursor.execute("""
            INSERT INTO chats (usuario_id, chat_id, titulo, fecha, mensajes)
            VALUES (%s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE titulo=%s, fecha=%s, mensajes=%s
        """, (chat.usuario_id, chat.chat_id, chat.titulo, chat.fecha, mensajes_json, chat.titulo, chat.fecha, mensajes_json))
        conn.commit()
        cursor.close()
        conn.close()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error al guardar")

@app.get("/cargar_chats/{usuario_id}")
async def cargar_chats(usuario_id: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT chat_id, titulo, fecha, mensajes FROM chats WHERE usuario_id=%s ORDER BY fecha DESC", (usuario_id,))
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        for row in rows:
            if isinstance(row["mensajes"], str):
                viejos = json.loads(row["mensajes"])
                # Conservamos 'ruta_video' al cargar el historial
                row["mensajes"] = [{'rol': m.get('rol') or m.get('role'), 'texto': m.get('texto') or m.get('content'), 'ruta_video': m.get('ruta_video')} for m in viejos if m.get('role') != 'system']
        return {"status": "ok", "chats": rows}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Error al cargar")

@app.post("/crear_incidencia")
async def crear_incidencia(t: dict):
    try:
        prompt_evaluador = """Eres un técnico IT evaluando un historial de chat. 
        Si el usuario NO tiene un problema técnico real, o si el problema YA FUE SOLUCIONADO durante la charla, responde ÚNICAMENTE con la palabra: FALSA_ALARMA. 
        Si hay un problema técnico real y NO se ha solucionado aún, genera un resumen muy breve (máximo 10 palabras) del problema."""

        chat_completion = groq_client.chat.completions.create(
            messages=[
                {"role": "system", "content": prompt_evaluador},
                {"role": "user", "content": t['problema']} 
            ],
            model="llama-3.3-70b-versatile",
            temperature=0.1,
            max_tokens=60,
        )
        
        resumen_problema = chat_completion.choices[0].message.content.strip().strip('"')

        if "FALSA_ALARMA" in resumen_problema.upper():
            return {"status": "ignorado", "mensaje": "No hay problema real o ya se resolvió."}

        conn = get_db_connection()
        cursor = conn.cursor()
        sql = "INSERT INTO incidencias (usuario, problema, urgencia, estado, fecha, departamento, email) VALUES (%s, %s, %s, 'pendiente', NOW(), %s, %s)"
        cursor.execute(sql, (t['usuario'], resumen_problema, t['urgencia'], t['departamento'], t['email']))
        conn.commit()
        cursor.close()
        conn.close()
        return {"status": "ok"}
    except Exception as e:
        print(f"Error en BD: {e}")
        return {"status": "error"}