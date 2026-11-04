import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ARRANQUE EN iOS (por qué este archivo está casi vacío y así debe quedar).
  //
  // El `LaunchScreen.storyboard` es una INSTANTÁNEA que el sistema pinta antes de
  // que exista este proceso: no se puede animar legalmente (UIKit pide un launch
  // screen «instantáneo y no interactivo», y una animación ahí es de lo más
  // rechaceable en Review) y en `didFinishLaunching` todavía no
  // hay ventana propia que mostrar, así que meter un `UIView` con un Lottie desde
  // aquí solo taparía el launch screen con un parpadeo.
  //
  // El diseño es: el storyboard pinta el frame 0 de `assets/lottie/splash.json`
  // sobre `#008C7B` y Flutter sigue con ESE MISMO frame en `_SplashLottie`
  // (`lib/src/core/widgets/splash_gate.dart`, activo solo cuando el target es
  // iOS). La animación vive del lado de Dart, no del lado del sistema. Todo el
  // detalle, en el comentario del propio storyboard.
}
