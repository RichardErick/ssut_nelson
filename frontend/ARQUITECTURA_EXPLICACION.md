Arquitectura del Sistema Frontend

El sistema frontend está construido sobre el patrón de arquitectura Modelo-Vista-Controlador (MVC), adaptado para el framework Flutter y utilizando el patrón "Provider" para la gestión del estado de forma reactiva. Esta arquitectura divide el software en capas distintas, asegurando que cada componente tenga una única y estricta responsabilidad.

Partes del sistema y la función que cumple cada una

El sistema se compone de cinco capas principales:

1. Vistas (Views / Screens)
Su función es exclusivamente la presentación visual y la captura de interacciones del usuario. No contienen lógica de negocio ni realizan llamadas a la red. Se construyen utilizando elementos gráficos. Estas vistas "escuchan" a los controladores de forma pasiva; cuando el controlador envía un aviso indicando que hay datos nuevos, la vista se redibuja automáticamente para mostrar la información más reciente al usuario.

2. Controladores (Controllers)
Actúan como el cerebro operativo de la aplicación y los gestores de la memoria a corto plazo (el estado). Su función incluye recibir las acciones y peticiones que vienen de la vista, interpretar qué significa esa acción, aplicar reglas de validación de datos, y decidir en qué momento solicitar información al servidor. Una vez que reciben los datos solicitados, actualizan sus variables internas y emiten una señal a las vistas para que estas se actualicen con los nuevos resultados.

3. Servicios (Services)
Su única función es la comunicación externa del sistema. Se encargan de encapsular todas las llamadas de red (conexiones a internet) dirigidas a la interfaz del backend. Los servicios reciben la información cruda transaccional (usualmente en texto formato JSON), manejan los errores de conexión a internet o de servidor, y delegan la conversión de ese texto plano en objetos estructurados.

4. Modelos (Models)
Son clases de datos puras que representan las entidades conceptuales del sistema (por ejemplo: un Documento, un Usuario, un Préstamo). Su función es estructurar la información para que sea segura de manejar dentro del código. Contienen rutinas de conversión de datos para traducir de manera exacta lo que llega del servidor a un formato que los controladores puedan manipular sin errores imprevistos.

5. API Backend
Es el servidor remoto desarrollado en la plataforma .NET Core con lenguaje C#. Su función es procesar centralmente la base de datos real, aplicar políticas de seguridad empresariales, verificar que quien hace las peticiones tenga permisos, y distribuir la información confirmada hacia el sistema frontend.

Cómo se comunican entre sí

La comunicación fluye de manera estrictamente direccional y secuencial. El flujo regular operativo funciona de la siguiente manera:

Paso 1: El usuario interactúa con un elemento gráfico en la Vista (por ejemplo, presiona un botón para cargar la lista de sus préstamos).

Paso 2: La Vista, que no sabe cómo obtener listas, simplemente invoca una función específica dentro del Controlador correspondiente.

Paso 3: El Controlador recibe el comando. Puede realizar validaciones previas y, si procede, ordena al Servicio que obtenga los préstamos. 

Paso 4: El Servicio construye el paquete de red necesario, adjunta tokens de autenticación de seguridad y envía la petición a través de internet al servidor API Backend en .NET Core.

Paso 5: El API Backend valida la solicitud, consulta su base de datos local y responde al frontend entregando los datos correctos empaquetados como texto estructurado.

Paso 6: El Servicio recibe esta respuesta de red. Utiliza la estructura definida en los Modelos para convertir ese texto estructurado en objetos programáticos reales en memoria, y se los entrega al Controlador.

Paso 7: El Controlador guarda esta colección de objetos en sus variables de estado y dispara una señal general indicando que su estado ha cambiado y está listo.

Paso 8: La Vista, que está configurada para reaccionar a las señales de su Controlador, detecta este cambio, lee las variables actualizadas y reconstruye la interfaz para que el usuario pueda ver sus datos en la pantalla.

Cómo se mantiene, escala y modifica

Mantenimiento:
La separación de responsabilidades hace que el código sea altamente predecible y el diagnóstico de problemas sea excepcionalmente rápido. Si la aplicación experimenta un error visual o de posicionamiento de un elemento, el desarrollador sabe que debe modificar únicamente los archivos de Vistas. Si la aplicación calcula un descuento de manera incorrecta, se audita exclusivamente el Controlador. Si la aplicación no logra conectarse, se investiga el Servicio. Esto evita tener que leer miles de líneas de código irrelevantes para encontrar la falla.

Escalabilidad:
El sistema permite un crecimiento estructurado continuo y seguro. Para integrar una característica totalmente nueva en el futuro (como un panel administrativo nuevo), el equipo técnico puede crear el nuevo Modelo, Servicio, Controlador y Vista correspondientes sin tocar o alterar el código de los módulos que ya funcionan, como los préstamos o documentos. Como el código de cada módulo está aislado en sus propios controladores, el proyecto puede tener cientos de pantallas sin volverse volátil y sin afectar el rendimiento de los módulos antiguos.

Modificación e Iteración:
La independencia de las capas permite reemplazos totales de componentes. Se puede rediseñar de cero una Interfaz Gráfica para hacerla más moderna, y mientras se mantenga la conexión a los mismos Controladores, todo funcionará desde el primer momento. Por su alta separación e independencia, esta arquitectura permite realizar pruebas automatizadas directamente sobre las reglas del Controlador sin requerir que la interfaz visual funcione o que haya conexión a internet disponible, asegurando estabilidad técnica.
