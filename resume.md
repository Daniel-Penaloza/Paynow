# PayNow — Resumen para nuevo dev

## Bloque 1 — Estructura y arranque

### ¿Qué es PayNow?
App Rails 8 que genera un QR por negocio. El cliente escanea, copia la CLABE y sube su comprobante. El dueño recibe notificación en tiempo real. Sin instalar nada, sin fricción.

---

### Tres roles
| Rol | Acceso |
|---|---|
| **Super Admin** | `lvh.me:3000` — administra toda la plataforma |
| **Business Owner** | `{subdomain}.lvh.me:3000/dashboard` — gestiona sus negocios |
| **Cliente final** | `{subdomain}.lvh.me:3000/p/{slug}` — sin cuenta, solo paga |

---

### Para arrancar el proyecto necesitas dos terminales

```bash
# Terminal 1 — servidor
bin/rails server -b 0.0.0.0 -p 3000

# Terminal 2 — CSS en vivo (sin esto Tailwind no compila)
bin/rails tailwindcss:watch
```

Y opcionalmente una tercera para la consola:
```bash
bin/rails console
```

---

### Tres servicios externos configurados en `.env`

| Variable | Servicio | Para qué |
|---|---|---|
| `ANTHROPIC_API_KEY` | Claude API | Verifica comprobantes con Vision |
| `TWILIO_ACCOUNT_SID` / `AUTH_TOKEN` | Twilio | Envía y recibe WhatsApp |
| `TWILIO_WHATSAPP_NUMBER` | Sandbox `+14155238886` | Número desde el que salen los mensajes |

---

### Cosas que te van a confundir al principio

**Los subdominios** — la app no funciona en `localhost:3000`. Usa `lvh.me` (dominio público que apunta a `127.0.0.1`) para simular subdominios sin tocar `/etc/hosts`.

**Los jobs en development** — corren automáticamente en un thread del servidor (adapter `:async`). En producción necesitan un worker de Solid Queue corriendo aparte.

**El inline `rails runner` con acentos** — falla por encoding. Siempre usar un archivo `.rb` para scripts con caracteres especiales.
