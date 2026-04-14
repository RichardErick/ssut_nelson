Para profundizar exclusivamente en las partes que componen el sistema, podemos desglosar cada capa en sus subcomponentes técnicos y organizativos. El sistema frontend no es solo una división de bloques generales, sino todo un ecosistema de piezas especializadas con roles muy específicos.

1. Capa de Presentación (Interfaz de Usuario)
Esta capa es lo que el usuario ve y toca directamente en la pantalla de su dispositivo. Se divide internamente en dos tipos de partes:
- Pantallas Principales (Screens/Views): Son los contenedores principales de una vista completa. Manejan la estructura base de la pantalla, como la barra superior de navegación, el menú lateral o inferior y el lienzo general en blanco (comúnmente llamado Scaffold). Su deber es organizar la distribución espacial de los elementos y preparar el terreno visual, pero no construirlos uno a uno.
- Componentes Reutilizables (Widgets): Son los ladrillos de construcción. En lugar de escribir el código de un botón repetidas veces en cada pantalla, el sistema tiene archivos que contienen pequeños bloques prefabricados (como "BotonAceptar", "TarjetaDePrestamo" o "BarraDeBusqueda"). Esta parte del sistema asegura que la aplicación se vea uniforme en todas partes y permite al equipo cambiar rediseños masivos modificando un solo archivo central.

2. Capa de Control y Memoria (Gestión de Estado)
Es uno de los bloques vitales de procesamiento en tiempo real. Se estructura en:
- Controladores Globales: Son archivos que mantienen la información viva a través de toda la sesión del usuario. Por ejemplo, un módulo de autenticación recuerda quién inició sesión, tu perfil y tus permisos, evitando consultar la base o obligarte a iniciar sesión cada vez que cambias de ventana.
- Controladores Locales de Tarea: Manejan procesos aislados, como una barra de carga que avanza de 0 a 100% mientras subes un documento. Existen únicamente en la memoria física mientras el usuario ejecuta la tarea; una vez finalizada, esta parte del sistema se autodestruye para liberar la saturación de memoria RAM en el celular o navegador.
- Gestor de Distribución (Provider Pattern): Su función es ser un sistema de tuberías invisible. Se encarga de inyectar sin escalas los datos de los Controladores directamente a los Componentes visuales que están ubicados en partes profundas de una pantalla, evitando que los desarrolladores tengan que pasar coordenadas manualmente ventana por ventana.

3. Capa de Acceso a Datos Ocultos (Servicios y Utilidades)
Aquí es donde el sistema interactúa con factores que el usuario jamás debe ver, como conexiones ocultas:
- Clientes Activos de Conexión (Servicios API): Son clases mecánicas preparadas para cruzar la red de internet. Estas partes tienen el trabajo de interceptar una petición, armar direcciones complejas (URLs), obligar a la conexión a utilizar llaves y tokens de seguridad asimétricos, y manejar elegantemente las crisis: si se cae el internet a la mitad de una orden, es esta capa la que arroja la instrucción de abortar para no congelar la pantalla.
- Utilidades Misceláneas (Utils y Helpers): Son el cajón de herramientas globales. Son funciones cortas que cualquier otra parte del sistema puede pedir prestadas. Contienen piezas como calculadoras de formato de dinero (agregando puntos decimales), traductores que cambian un texto técnico rígido "2026-03-22T10:43" a formatos legibles e incluso rutinas técnicas abstractas.

4. Capa de Estructura Física (Modelos Entidades)
Son los esqueletos matemáticos que el lenguaje de programación protege firmemente.
- Entidades de Dominio Central: Son un reflejo de los conceptos de la empresa. Garantizan mediante tipado fuerte que, por ejemplo, una vez que la pantalla carga a un "Usuario", este objeto tiene un nombre, una edad numérica obligatoria y un folio. El sistema nunca permite procesar a alguien que no cumpla esa "forma".
- Filtros de Traducción Serializada: Es una sub-función dentro del Modelo fundamental. Actúa como el filtro aduanal de programación; cuando el "Servicio de Conexión" toma el archivo desde el servidor Backend, entrega millones de líneas de texto incomprensible. El Filtro de Traducción corre línea por línea transformando el texto inerte en objetos con vida real en la memoria, descartando la información basura e integrando la útil para pasársela filtrada y probada al Controlador.

Entendiendo así las partes, se observa que la composición del sistema está basada en el ensamble escalonado: la estructura física valida, las conexiones extraen, la memoria reordena y retiene, y por fin la capa de distribución dibuja en la pantalla los botones.
