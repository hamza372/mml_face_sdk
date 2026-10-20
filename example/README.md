# MML Face SDK example

This app demonstrates activation, model installation, local enrollment,
one-to-one face matching, and passive liveness. Biometric processing stays on
the device.

## Customer evaluation

Run without a bundled activation key and enter the seven-day trial key supplied
for your exact Android package name or iOS bundle identifier:

```sh
flutter run \
  --dart-define=MML_LICENSE_PUBLIC_KEY=PUBLIC_KEY \
  --dart-define=MML_ACTIVATION_URL=ACTIVATION_URL
```

## Running or building the public demo

The example contains a demo-only activation key restricted to its Android
package identifier, so it runs without asking the user for a key:

```sh
flutter run
```

The key can be replaced for an internal build when needed:

```sh
flutter run --dart-define=MML_DEMO_ACTIVATION_KEY=ANOTHER_DEMO_ONLY_KEY
```

Never put a commercial customer key in this example. For production
integration, store the returned signed licence token in platform secure
storage and follow the package's integration guide.
