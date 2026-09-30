# Gerador de Panfletos (Flutter)

Projeto-fonte. Este zip NÃO contém as pastas android/ e windows/: elas são geradas por
`flutter create` (o workflow do GitHub já faz isso sozinho).

## Jeito 1 – GitHub (não precisa instalar nada)
1. Crie um repositório no github.com e envie todo o conteúdo desta pasta (inclusive .github).
2. Aba Actions > "Gerar APK e EXE" > Run workflow.
3. Quando terminar (~10 min), baixe em "Artifacts": o .apk (Android) e a pasta do Windows.

## Jeito 2 – No seu computador
1. Instale o Flutter (docs.flutter.dev/get-started/install), Android Studio (para o APK)
   e Visual Studio com "Desenvolvimento para desktop com C++" (para o .exe).
2. Na pasta do projeto:
   flutter create --platforms=android,windows .
   (Android) troque `flutter.minSdkVersion` por `24` em android/app/build.gradle*
3. Baixe u2netp.onnx (link em assets/models/) e coloque em assets/models/.
4. flutter pub get
   flutter build apk --release      -> build/app/outputs/flutter-apk/app-release.apk
   flutter build windows --release  -> build/windows/x64/runner/Release/
