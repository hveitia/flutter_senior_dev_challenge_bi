# Componentes y dependencias

Qué paquetes forman la aplicación móvil, de qué depende cada uno y por qué las flechas van en ese sentido. Describe lo construido hasta la etapa 6. La consola web, la API de servidor y los dominios de transferencias, notificaciones y servicios se añadirán en sus etapas.

## Paquetes

```mermaid
flowchart TB
  subgraph app[apps/mobile · raíz de composición]
    composicion[Composición<br/>dependencias, registro de módulos]
    rutas[Rutas y resolutor de destinos]
    alcance[Alcance del cliente<br/>cuentas, configuración, fallos publicados]
  end

  subgraph dominios[Paquetes de dominio]
    auth[feature_auth<br/>registro, sesión, desbloqueo]
    accounts[feature_accounts<br/>cuentas, movimientos<br/>módulos: saldo, cuentas, últimos movimientos]
    home[feature_home<br/>motor del inicio<br/>módulos: acciones rápidas, banner]
  end

  subgraph base[Paquetes compartidos]
    kit[module_kit<br/>registro de módulos, destinos, aviso de conexión]
    platform[app_platform<br/>configuración, resiliencia, conectividad, telemetría]
    ds[design_system<br/>tokens, tema, componentes]
  end

  subgraph externos[Servicios]
    fauth[(Firebase Auth)]
    fs[(Firestore)]
    obs[(Crashlytics, Analytics, Performance)]
  end

  app --> auth
  app --> accounts
  app --> home
  app --> kit

  auth --> platform
  auth --> ds
  accounts --> kit
  accounts --> platform
  accounts --> ds
  home --> kit
  home --> platform
  home --> ds
  kit --> platform
  kit --> ds

  auth -. adaptadores .-> fauth
  auth -. adaptadores .-> fs
  accounts -. adaptadores .-> fs
  platform -. adaptadores .-> fs
  platform -. adaptadores .-> obs
```

## Reglas que el diagrama expresa

| Regla | Cómo se garantiza |
|---|---|
| Un dominio no importa a otro dominio | Cada paquete declara sus dependencias en su `pubspec.yaml`; una prueba de arquitectura por paquete lista los paquetes permitidos y falla ante cualquier otro |
| El inicio no conoce los dominios | `feature_home` depende de `module_kit`, no de `feature_accounts`. Dibuja lo que cada dominio registró |
| Firebase y los plugins solo se tocan desde los adaptadores | Las líneas punteadas. El código de dominio y de presentación habla con interfaces; los adaptadores están en una carpeta aparte y solo los importa la raíz de composición |
| El código puro de la plataforma no importa Flutter | Prueba de arquitectura de `app_platform` |
| La raíz de composición es el único lugar que conoce las implementaciones | `apps/mobile/lib/composition.dart` construye repositorios, política, registro de módulos y resolutor de destinos |

## Qué aporta cada paquete al inicio

```mermaid
flowchart LR
  config[(config/home)] --> cubit[RemoteConfigCubit<br/>app_platform]
  cubit --> composicion[HomeCompositionCubit<br/>feature_home]
  registro[HomeModuleRegistry<br/>module_kit] --> composicion
  composicion --> pantalla[HomeScreen]

  accounts[feature_accounts] -- registra --> registro
  home[feature_home] -- registra --> registro

  pantalla --> saldo[totalBalance]
  pantalla --> carrusel[accountCarousel]
  pantalla --> movimientos[recentMovements]
  pantalla --> acciones[quickActions]
  pantalla --> banner[promoBanner]

  saldo --> ab[AccountsBloc]
  carrusel --> ab
  movimientos --> rb[RecentMovementsBloc]
```

- El saldo y el carrusel muestran el mismo conjunto de datos, las cuentas, y comparten su estado. Los últimos movimientos tienen el suyo. Por eso una falla del servicio de movimientos deja el saldo y las cuentas en pantalla.
- Las acciones rápidas y el banner no tienen datos: se dibujan con lo que la configuración publica y preguntan al resolutor de destinos qué pueden abrir.
- Los tipos `investmentSummary` y `serviceRecommendations` aparecen en la configuración publicada y ningún paquete los registra todavía. El inicio los omite.

La decisión y sus alternativas están en el [ADR 0013](../adr/0013-registro-de-modulos-y-motor-del-inicio.md).
