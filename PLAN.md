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

- [x] Dashboard de comprobantes con filtros por período y rango de fechas
- [x] Contabilidad: suma de comprobantes por día / semana / mes / año
- [x] Clientes frecuentes (identificación por datos capturados en comprobante)
- [ ] Exportar reporte de comprobantes (CSV/Excel)
- [x] Recepción de comprobantes por WhatsApp (Twilio webhook — cliente envía foto al número del negocio)
- [x] Notificación WhatsApp al cliente (pagador) tras verificación del comprobante
- [x] Mensajes de error amigables en webhook de WhatsApp
- [x] Notificación por WhatsApp al dueño del negocio
- [ ] Vista de comprobante con status (pendiente / confirmado / rechazado)
- [ ] Planes / suscripción por organización (si se monetiza)
- [ ] Suite de pruebas con RSpec (models, requests, system specs)

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
- [x] Dashboard de comprobantes con filtros (Hoy / Esta semana / Este mes / Este año / Rango personalizado)
- [x] Totales de ingresos verificados por período en dashboard del negocio (Hoy / Semana / Mes / Año)
- [x] Clientes frecuentes — formulario opcional en landing con disclaimer + vista agrupada en dashboard
- [x] Vistas detalladas de ingresos por período — cada tarjeta de contabilidad (Hoy / Semana / Mes / Año) enlaza a una tabla con todos los comprobantes verificados de ese período
- [x] Exportar a Excel desde las vistas detalladas — botón que descarga `.xlsx` con los datos de la tabla

### Fase 3 — Extracción inteligente de comprobantes (Claude Vision)

**Objetivo:** verificar automáticamente que cada comprobante sea una transferencia bancaria válida, extraer el monto y la fecha para alimentar la contabilidad. Funciona con todos los bancos y neobancos de México (BBVA, Nu, Santander, Banorte, HSBC, Hey Banco, Mercado Pago, Spin, Clip, Klar, Albo, Stori, Fondeadora, etc.).

**Flujo:**
1. Cliente sube comprobante → Receipt se crea con status `pending`
2. `ReceiptVerificationJob` se encola automáticamente
3. El job manda la imagen a Claude API (vision)
4. Claude responde JSON estructurado con los campos extraídos
5. Se valida tipo y fecha → Receipt se actualiza con status y monto
6. Turbo Stream notifica al dashboard en tiempo real

#### Base de datos
- [x] Migración: agregar `amount_cents` (integer), `transfer_date` (date), `bank_name` (string), `reference_number` (string), `verification_status` (string, default: `pending`), `verification_notes` (text) al modelo `Receipt`

#### Modelo
- [x] Scopes y validaciones nuevas en `Receipt` para los campos extraídos
- [x] Callback `after_create_commit` para encolar `ReceiptVerificationJob`

#### Job de verificación
- [x] Crear `ReceiptVerificationJob` con ActiveJob + Solid Queue
- [x] Convertir archivo adjunto a base64 (imágenes PNG/JPG)
- [x] Soporte para PDFs: convertir primera página a imagen con `mini_magick` antes de mandar a Claude
- [x] Integración con Claude API (vision) — prompt estructurado que devuelve JSON con: `{ is_transfer, transfer_date, amount, bank_name, reference_number, notes }`
- [x] Lógica de validación: verificar que sea transferencia + que la fecha sea la actual
- [x] Actualizar el `Receipt` con los datos extraídos y el `verification_status` correspondiente

#### Dashboard
- [x] Badge de status en lista de comprobantes (`pending` / `verified` / `rejected` / `unreadable`)
- [x] Mostrar monto extraído en la tarjeta del comprobante
- [x] Vista `show` del comprobante con todos los campos extraídos (banco, monto, fecha, referencia, notas)
- [x] Turbo Stream que actualiza el badge y monto en tiempo real cuando el job termina

#### Contabilidad (Fase 2 desbloqueada por esta fase)
- [x] Totales por período en el dashboard usando `amount_cents` + `transfer_date`
- [x] Solo contar comprobantes con `verification_status: verified`

### Fase 4 — Pulido y escala
- [x] Integración WhatsApp Business API via Twilio (recepción de comprobantes + notificación al cliente + notificación al dueño)
- [ ] Exportación de reportes (CSV/Excel)
  - [x] Vista detallada de ingresos por período (Hoy / Semana / Mes / Año) con tabla de comprobantes verificados
  - [x] Botón "Exportar a Excel" en cada vista detallada → descarga `.xlsx` con: fecha, pagador, banco, referencia, monto
- [ ] Planes / suscripción por organización (monetización) → ver Fase 6

### Fase 5 — Pruebas con RSpec
- [x] Setup de RSpec + FactoryBot + Shoulda Matchers
- [x] Remover Minitest (carpeta `test/` eliminada)
- [x] Model specs: Organization, User, Business, Receipt (validaciones, scopes, callbacks)
- [x] Helper specs: `ApplicationHelper#receipt_status_badge`
- [x] Job specs: `ReceiptVerificationJob` con stubs de Claude API, Turbo y WhatsApp
- [x] Request specs: autenticación (login, logout, cookie de sesión)
- [x] Request specs: CRUD de negocios con protección de autenticación y autorización
- [x] Request specs: filtros de comprobantes (period, date_from/date_to), reprocess con Turbo Stream
- [x] Request specs: landing page pública con subdomain routing (`host!`)
- [x] Request specs: Admin controllers (Organizations, Users) con protección de `super_admin`
- [x] Request specs: `Webhooks::TwilioController`
- [x] System specs (Capybara): flujo completo de subida de comprobante
- [x] System specs (Capybara): suscripción Turbo Stream + badges de status + contabilidad

### Infraestructura de desarrollo
- [x] Servidor enlazado a `0.0.0.0` para acceso desde red local
- [x] dnsmasq resolviendo `*.lvh.me → 192.168.68.101` para subdominios desde celular
- [x] Pruebas end-to-end desde celular vía ngrok (ruta `/dev/pay/:org_subdomain/:slug`)
- [ ] Deploy en Fly.io

---

### Fase 6 — Monetización (Planes Básico y Pro)

#### Base de datos
- [ ] Migración: agregar `plan` (enum: `free | basic | pro`, default `free`) a `Organization`
- [ ] Migración: agregar `plan_status` (enum: `trialing | active | inactive`, default `trialing`) a `Organization`
- [ ] Migración: agregar `trial_ends_at` (date) y `current_period_ends_at` (date) a `Organization`

#### Modelo
- [ ] Validaciones y scopes en `Organization`: `on_trial?`, `plan_active?`, `within_business_limit?`, `within_receipt_limit?`
- [ ] Límites por plan:
  - `free` / `trialing`: 1 negocio, 50 comprobantes/mes (período de prueba 14 días)
  - `basic`: 1 negocio, 500 comprobantes/mes
  - `pro`: 5 negocios, comprobantes ilimitados

#### Enforcement (restricciones en controllers)
- [ ] `Dashboard::BusinessesController#create` — bloquear si se excede el límite de negocios del plan
- [ ] `Public::PaymentsController#submit_receipt` — bloquear si se excede el límite mensual de comprobantes
- [ ] Mensaje de error claro con invitación a hacer upgrade

#### Panel de administración
- [ ] `Admin::OrganizationsController` — poder asignar plan y fechas manualmente (para onboarding manual inicial)
- [ ] Vista `show` de organización muestra plan actual, uso del mes (negocios activos, comprobantes del período)

#### Dashboard del Business Owner
- [ ] Widget de uso en el overview: "X de 500 comprobantes usados este mes" con barra de progreso
- [ ] Banner de aviso cuando quede < 20% de cuota disponible
- [ ] Banner de trial: "Tu período de prueba termina en X días — elige un plan"
- [ ] Página `/dashboard/subscription` con resumen del plan actual y botón de upgrade

#### Cobro con Stripe
- [ ] Instalar gem `stripe` y configurar webhook endpoint `POST /webhooks/stripe`
- [ ] Crear productos y precios en Stripe: Básico ($199 MXN/mes), Pro ($349 MXN/mes)
- [ ] Stripe Checkout: al hacer clic en "Upgrade" redirige a sesión de pago alojada por Stripe
- [ ] Webhook `customer.subscription.updated` / `invoice.paid` / `invoice.payment_failed` actualiza `plan`, `plan_status` y `current_period_ends_at` en `Organization`
- [ ] Soporte para OXXO Pay (método de pago muy usado en México, disponible en Stripe)
- [ ] Email de confirmación de pago (Action Mailer)

#### Facturación México (CFDI)
- [ ] Integración con Facturapi (API mexicana de timbrado CFDI) o Billpocket
- [ ] Emitir CFDI automáticamente tras cada pago exitoso de Stripe
- [ ] Enviar XML + PDF por correo al cliente

---

## Próximos pasos (siguiente sesión)

1. **Fase 6 — Monetización**: empezar por base de datos + modelo + enforcement (sin Stripe aún — primero las restricciones funcionan, luego el cobro).
2. **Deploy en Fly.io** — configurar variables de entorno (`ANTHROPIC_API_KEY`, `TWILIO_*`, `SECRET_KEY_BASE`, base de datos en producción).

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

---

## Plan de monetización

### Costo por comprobante procesado

| Componente | USD | MXN (≈$17.5) |
|---|---|---|
| Claude Haiku visión (~640 tokens entrada + 100 salida) | $0.0011 | $0.02 |
| Twilio WhatsApp (3 mensajes: inbound + confirmación + resultado) | $0.0150 | $0.26 |
| **Total por comprobante** | **$0.016** | **$0.28** |

> Twilio domina el costo variable. Claude es prácticamente gratuito a esta escala.

### Costos fijos mensuales (plataforma)

| Concepto | USD/mes | MXN/mes |
|---|---|---|
| Fly.io (Rails app + Postgres + 5 GB storage) | $15 | $263 |
| Claude Pro × 3 devs (mantenimiento) | $60 | — (gasto del equipo, no de la empresa) |

### Planes

**Plan Básico — $199 MXN/mes** *(+ IVA = $231 MXN)*
- 1 negocio
- Hasta 500 comprobantes/mes
- WhatsApp incluido
- Dashboard + exportación Excel

**Plan Pro — $349 MXN/mes** *(+ IVA = $405 MXN)*
- Hasta 5 negocios
- Comprobantes ilimitados
- Todo lo del Básico

### Proyección de rentabilidad (70% Básico / 30% Pro, ~300 comp/mes promedio)

| Clientes | Ingreso bruto | Costos var + fijos | Neto post-ISR (~20%) |
|---|---|---|---|
| 10 | $2,440 MXN | $1,110 MXN | $1,064 MXN |
| 25 | $6,025 MXN | $2,381 MXN | $2,915 MXN |
| 50 | $12,200 MXN | $4,499 MXN | $6,161 MXN |
| 100 | $24,400 MXN | $8,736 MXN | $12,531 MXN |
| 200 | $48,800 MXN | $17,210 MXN | $25,272 MXN |

> Con **25-30 clientes** el producto ya cubre infraestructura y genera utilidad.
> Objetivo año 1: **50 negocios** (taquerías, abarrotes, cafeterías, mercados).

### Consideraciones fiscales México

- **Régimen recomendado**: RESICO si ingresos anuales < $3.5M MXN — tasa ISR del 1% al 2.5% sobre ingresos brutos
- **IVA**: Cobrar 16% adicional. El cliente lo paga, se declara mensualmente al SAT
- **CFDI**: Emitir factura por cada cobro de suscripción
- **Estructura legal**: Evaluar persona moral (SA de CV) vs personas físicas independientes según escala

### Palanca de reducción de costos a futuro

El mayor costo variable es Twilio ($0.015/comprobante). Migrar a **Meta WhatsApp Business API directa** reduce ese costo a ~$0.002/mensaje, bajando el costo variable por comprobante de $0.28 a ~$0.06 MXN. Recomendable cuando superes los 200 clientes.
