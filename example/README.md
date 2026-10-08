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

## Building the public demo

The downloadable demo is built separately with a demo-only activation key that
is restricted to this example application's package identifier:

```sh
flutter build apk --release \
  --dart-define=MML_DEMO_ACTIVATION_KEY=DEMO_ONLY_KEY
```

Never commit commercial or demo activation keys. For production integration,
store the returned signed licence token in platform secure storage and follow
the package's integration guide.
