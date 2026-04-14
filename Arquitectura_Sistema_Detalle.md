# Documentación de Arquitectura de Desarrollo y Ejecución

Esta sección describe el flujo de trabajo de desarrollo y el entorno de ejecución del sistema, basado en la arquitectura diseñada.

---

## 1. Entorno de Desarrollo (Desarrollo)

El entorno de desarrollo está centralizado en el uso de herramientas modernas que facilitan la creación y depuración del software antes de su puesta en producción.

**Herramientas Principales:**
- **Antigravity AI**: Asistente de codificación avanzado para la generación y optimización de código.
- **Postman**: Utilizado para las pruebas de endpoints de la API RESTful.
- **Git / GitHub**: Gestión de control de versiones y almacenamiento de repositorios para el Cliente y el Servidor.
- **ngrok**: Herramienta para exponer servicios locales a Internet de forma segura.
- **Docker**: Contenedorización de servicios locales.

**Proceso de Desarrollo:**
1. El desarrollador utiliza **Antigravity** para interactuar con el código base.
2. Se gestionan dos repositorios principales: **Cliente** (React/Web) y **Servidor** (Node/C#).
3. La comunicación entre el entorno local y servicios externos se facilita mediante **MCP (Model Context Protocol)** y **ngrok**.

---

## 2. Entorno de Ejecución (Ejecución)

Describe cómo interactúan los componentes en un entorno real de operación una vez desplegados.

### 2.1 Componente Cliente (Frontend)
El cliente interactúa directamente con el usuario mediante un navegador web.
- **Tecnologías**: React, Socket.io para comunicación en tiempo real.
- **Interacción**: Realiza peticiones (Requests) mediante **HTTP/JSON** a través de túneles **ngrok** hacia el servidor.

### 2.2 Componente Servidor (Backend)
El núcleo del sistema gestiona la lógica y la comunicación con otros servicios.
- **Frameworks**: Node.js / Express (o ASP.NET Core según el proyecto).
- **Validación y DTO**: Uso de validadores (ej. Zod) y Objetos de Transferencia de Datos (DTO) para asegurar la integridad de la información.
- **Comunicación**: Métodos estándar (GET, POST, PUT, DELETE) y Socket.io para procesos síncronos.

### 2.3 Servicios y Persistencia
- **Servicios Externos**: Integración con servicios de correo y plataformas de terceros (Libélula).
- **Capa de Datos**:
    - **Base de Datos**: PostgreSQL ejecutándose en entornos Dockerizados.
    - **ORM (Object-Relational Mapping)**: Uso de Prisma u otros ORMs para convertir lógica de código en consultas SQL eficientes.

---

## 3. Flujo de Comunicación
- El **Navegador (Internet)** envía una petición hacia el túnel de **ngrok**.
- **ngrok** reenvía la petición al **Servidor** mediante **HTTP JSON**.
- El **Servidor** procesa la petición, interactúa con la **Base de Datos** mediante el **ORM**, y devuelve una respuesta estructurada al **Cliente**.
- Se mantiene una conexión bidireccional mediante **Socket.io** para actualizaciones en tiempo real cuando es necesario.
