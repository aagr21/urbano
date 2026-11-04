# LaunchImage

No es el `LaunchImage` vacío de la plantilla de Flutter: ahora es **el frame 0 de
`assets/lottie/splash.json`**, la imagen que dibuja `LaunchScreen.storyboard`.

El launch screen de iOS no se puede animar (Apple lo captura como instantánea
antes de crear el proceso y rechaza cualquier animación ahí), así que la
continuidad con la animación se hace con la imagen: el storyboard pinta este
frame 0 sobre `#008C7B` y, en cuanto Flutter puede dibujar, `_SplashLottie`
(`lib/src/core/widgets/splash_gate.dart`) arranca ese mismo JSON desde ese mismo
frame. Mismo verde, mismo aro, misma micro en el mismo ángulo.

Para regenerar los tres PNG (necesita `resvg` o `rsvg-convert`):

    tools/make-ios-splash-frame0.sh

La pose se corrige en `assets/lottie/splash-frame0.svg`, no en los PNG. Si cambia
la animación del JSON, cambia el SVG y vuelve a correr el script.
