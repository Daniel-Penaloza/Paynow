# Plan del Proyecto — PayNow

## El problema

En México muchos negocios informales solo aceptan efectivo o transferencias bancarias (CLABE/SPEI),
no tarjetas. El proceso actual para hacer una transferencia es lento y propenso a errores:

- El cliente tiene que leer una hoja con CLABE, nombre del titular, WhatsApp, instrucciones
- Tiene que escribir la CLABE manualmente en su banco (riesgo de error)
- Tiene que enviar el comprobante por WhatsApp (requiere tener el contacto guardado)
- Para personas poco familiarizadas con tecnología puede tomar hasta 15 minutos

## La solución

**QR Code + Landing page de pago** — sin instalar nada, todo desde el navegador.

### Flujo del dueño del negocio
1. El administrador del negocio se registra y crea sus negocios con su info de pago
2. El sistema genera un **QR único** por negocio
3. El negocio imprime el QR y lo coloca en el mostrador

### Flujo del cliente final (quien paga)
1. Escanea el QR con la cámara del celular
2. Ve una landing page con:
   - Nombre del negocio
   - CLABE con botón **"Copiar con un tap"**
   - Nombre del titular
   - Instrucciones simplificadas
3. Va a su banco, pega la CLABE, hace la transferencia
4. Regresa a la misma página y sube foto del comprobante
5. El dueño del negocio recibe **notificación en tiempo real**

### Qué resuelve
- Elimina errores al escribir la CLABE
- Cero necesidad de guardar contactos para enviar comprobante
- Reduce el proceso de ~15 minutos a ~2 minutos
- El dueño recibe alerta directa, no un WhatsApp perdido
- Funciona para cualquier banco, cualquier negocio informal

---

## Roles y permisos

### Super Admin (tú — dueño de la plataforma)
- Crear y gestionar organizaciones (clientes de la plataforma)
- Ver y controlar todos los usuarios
- Acceso global a datos

### Business Owner (cliente de la plataforma — autogestionable)
- Registrar múltiples negocios, cada uno con su propia CLABE e info bancaria
- Generar QR por negocio
- Ver comprobantes recibidos
- Contabilidad automática generada a partir de los comprobantes:
  - Totales por día / semana / mes / año
- Identificar clientes frecuentes (por nombre, email o teléfono capturado al subir comprobante)
- Recibir notificaciones en tiempo real al llegar un comprobante

### Cliente final (quien escanea y paga)
- Sin cuenta — flujo 100% anónimo y sin fricción
- Solo escanea, copia CLABE, transfiere y sube comprobante

---

## Funcionalidades — MVP (primera iteración)

### Super Admin
- [x] CRUD de organizaciones (Business Owners)
- [x] Panel de control global

### Business Owner
- [x] Registro / login
- [x] CRUD de negocios (nombre, CLABE, titular, WhatsApp, instrucciones)
- [x] Generación de QR por negocio
- [x] Vista de comprobantes recibidos
- [x] Notificación en tiempo real al llegar comprobante (Turbo Streams)

### Cliente final
- [x] Landing page de pago por QR (sin login)
- [x] Botón "Copiar CLABE"
- [x] Subir comprobante (foto o PDF)
- [x] Confirmación visual de envío exitoso

## Funcionalidades — siguientes iteraciones

- [ ] Contabilidad: suma de comprobantes por día / semana / mes / año
- [ ] Clientes frecuentes (identificación por datos capturados en comprobante)
- [ ] Exportar reporte de comprobantes (CSV/PDF)
- [ ] Notificación por WhatsApp al dueño del negocio
- [ ] Monto sugerido editable en la landing page (ej. "Tu total es $450")
- [ ] Vista de comprobante con status (pendiente / confirmado / rechazado)
- [ ] Planes / suscripción por organización (si se monetiza)

---

## Stack tecnológico

| Capa | Tecnología | Razón |
|---|---|---|
| Backend | **Ruby on Rails 8** | Familiaridad, velocidad de desarrollo |
| Frontend | **Hotwire (Turbo + Stimulus)** | Tiempo real sin JS complejo |
| Base de datos | **PostgreSQL** | Robusto, soporte JSON, ideal para contabilidad |
| Archivos | **Active Storage** | Subida de comprobantes (foto/PDF) |
| QR codes | **rqrcode gem** | Generación de QR nativamente en Rails |
| Autenticación | **Rails 8 Authentication Generator** | Built-in, sin dependencias extras |
| Estilos | **Tailwind CSS** | Rápido de usar, mobile-first |
| Tiempo real | **Turbo Streams + ActionCable** | Notificaciones sin recargar la página |
| Deployment | **Fly.io** | Simple para Rails, buen free tier para iterar |

---

## Arquitectura de modelos (borrador)

```
User (Business Owner)
  └── belongs_to Organization
  └── has_many Businesses

Organization
  └── has_many Users

Business
  └── belongs_to User
  └── has_one QrCode
  └── has_many Receipts (comprobantes)

Receipt
  └── belongs_to Business
  └── has_one_attached file (Active Storage)
  └── submitted_at
```

---

## Hoja de ruta

### Fase 1 — MVP funcional
- [ ] Setup del proyecto Rails 8 + Tailwind + Hotwire
- [ ] Autenticación (Super Admin + Business Owner)
- [ ] CRUD de organizaciones y negocios
- [ ] Generación de QR por negocio
- [ ] Landing page pública de pago (ruta sin auth)
- [ ] Subida de comprobantes con Active Storage
- [ ] Notificación en tiempo real con Turbo Streams
- [ ] Deploy en Fly.io

### Fase 2 — Valor para el Business Owner
- [ ] Dashboard de comprobantes con filtros
- [ ] Contabilidad básica (totales por período)
- [ ] Clientes frecuentes

### Fase 3 — Pulido y escala
- [ ] Notificaciones WhatsApp
- [ ] Exportación de reportes
- [ ] Gestión de status de comprobantes
- [ ] Monetización / planes

### Infraestructura de desarrollo
- [x] Servidor enlazado a `0.0.0.0` para acceso desde red local
- [x] dnsmasq resolviendo `*.lvh.me → 192.168.68.101` para subdominios desde celular
- [ ] Configurar DNS manual en celular (`192.168.68.101`) para pruebas end-to-end

---

## Decisiones tomadas

| Decisión | Resolución |
|---|---|
| Validación de comprobantes | Sin validación manual en MVP — recibirlo es suficiente |
| Datos del cliente final | Flujo 100% anónimo — no se captura nombre ni teléfono |
| URLs de negocios | Subdominio por organización: `org.paynow.mx/p/negocio-slug` |

### Implicaciones técnicas
- El modelo `Receipt` no necesita campos de pagador (payer_name, payer_phone) en MVP
- La landing page de pago vive en el subdominio de la organización
- Rails necesita configuración de `config.hosts` y routing por subdominio
- En desarrollo se usará `org.lvh.me` (resuelve a localhost sin tocar /etc/hosts)
