import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mml_face_sdk/mml_face_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MML Face SDK',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff19c5b6),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfff4f7fb),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff3f6fa),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const DemoHome(),
  );
}

class EnrolledProfile {
  const EnrolledProfile({required this.name, required this.template});

  final String name;
  final FaceTemplate template;

  Map<String, Object> toJson() => {
    'version': 1,
    'name': name,
    'template': template.toJson(),
  };

  factory EnrolledProfile.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 || json['name'] is! String) {
      throw const FormatException('Invalid profile');
    }
    return EnrolledProfile(
      name: (json['name']! as String).trim(),
      template: FaceTemplate.fromJson(
        (json['template']! as Map).cast<String, Object?>(),
      ),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const publicKeyB64 = String.fromEnvironment(
    'MML_LICENSE_PUBLIC_KEY',
    defaultValue: 'vJZyhTYJIS4JWop8tIlY1Juyzpyv434M_BUQhgHzgDY',
  );
  static const activationUrl = String.fromEnvironment(
    'MML_ACTIVATION_URL',
    defaultValue:
        'https://mml-face-license.hamzaasif19974-69b.workers.dev/v1/activate',
  );
  static const demoActivationKey = String.fromEnvironment(
    'MML_DEMO_ACTIVATION_KEY',
  );

  final activationCode = TextEditingController();
  MmlFaceSdk? sdk;
  EnrolledProfile? profile;
  String status = 'Starting secure face engine…';
  bool ready = false;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    sdk = MmlFaceSdk(
      matchThreshold: .75,
      publicLicenseKey: SimplePublicKey(
        base64Url.decode(base64Url.normalize(publicKeyB64)),
        type: KeyPairType.ed25519,
      ),
    );
    try {
      final token = await storage.read(key: 'license');
      if (token != null) {
        await sdk!.initialize(license: token);
      } else if (demoActivationKey.isNotEmpty) {
        await _activateWithCode(demoActivationKey);
      }
      await _loadProfile();
      if (!mounted) return;
      setState(() {
        ready = token != null || demoActivationKey.isNotEmpty;
        busy = false;
        status = ready ? 'On-device engine ready' : 'Activation required';
      });
    } catch (_) {
      if (demoActivationKey.isNotEmpty) {
        try {
          await _activateWithCode(demoActivationKey);
          await _loadProfile();
          if (!mounted) return;
          setState(() {
            ready = true;
            busy = false;
            status = 'On-device engine ready';
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        ready = false;
        busy = false;
        status = 'Activation required';
      });
    }
  }

  Future<void> _loadProfile() async {
    final savedProfile = await storage.read(key: 'profile');
    if (savedProfile != null) {
      profile = EnrolledProfile.fromJson(jsonDecode(savedProfile));
      return;
    }
    final legacyTemplate = await storage.read(key: 'template');
    if (legacyTemplate != null) {
      profile = EnrolledProfile(
        name: 'Enrolled user',
        template: FaceTemplate.fromJson(jsonDecode(legacyTemplate)),
      );
      await storage.write(key: 'profile', value: jsonEncode(profile));
      await storage.delete(key: 'template');
    }
  }

  Future<void> _activateWithCode(String code) async {
    final token = await sdk!.activate(
      endpoint: Uri.parse(activationUrl),
      activationCode: code,
    );
    await storage.write(key: 'license', value: token);
  }

  Future<void> _activate() async {
    if (busy || activationCode.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      status = 'Activating licence and installing models…';
    });
    try {
      await _activateWithCode(activationCode.text.trim());
      if (!mounted) return;
      setState(() {
        ready = true;
        status = 'On-device engine ready';
      });
    } catch (_) {
      if (mounted) setState(() => status = 'Activation failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openEnrollment() async {
    final enrolled = await Navigator.of(context).push<EnrolledProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EnrollmentCameraPage(sdk: sdk!, existingName: profile?.name),
      ),
    );
    if (enrolled == null) return;
    await storage.write(key: 'profile', value: jsonEncode(enrolled));
    if (!mounted) return;
    setState(() {
      profile = enrolled;
      status = '${enrolled.name} is enrolled on this device';
    });
  }

  Future<void> _openVerification(bool liveness) async {
    final enrolled = profile;
    if (!ready || enrolled == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LiveVerificationPage(
          sdk: sdk!,
          profile: enrolled,
          requireLiveness: liveness,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = profile;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                22,
                MediaQuery.paddingOf(context).top + 22,
                22,
                30,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff071a2e), Color(0xff123b4a)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xff19c5b6),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MML FACE SDK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'Private, on-device verification',
                              style: TextStyle(color: Color(0xffa8c3cd)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.shield_outlined, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Face verification\nthat stays on device.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff19c5b6),
                          ),
                        )
                      else
                        Icon(
                          ready ? Icons.check_circle : Icons.info_outline,
                          size: 19,
                          color: ready ? const Color(0xff56dfbd) : Colors.amber,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Color(0xffd7e6ea),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
            sliver: SliverList.list(
              children: [
                if (demoActivationKey.isEmpty && !ready) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardTitle(
                          icon: Icons.key_outlined,
                          title: 'Activate SDK',
                          subtitle: 'Enter the key issued for this app.',
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: activationCode,
                          decoration: const InputDecoration(
                            labelText: 'Customer app licence key',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy ? null : _activate,
                            child: const Text('Activate securely'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardTitle(
                        icon: enrolled == null
                            ? Icons.person_add_alt_1
                            : Icons.verified_user_outlined,
                        title: enrolled == null
                            ? 'Register a face'
                            : enrolled.name,
                        subtitle: enrolled == null
                            ? 'Capture one clear photo and add a name.'
                            : 'Face profile saved locally on this device.',
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: ready && !busy ? _openEnrollment : null,
                          icon: Icon(
                            enrolled == null
                                ? Icons.camera_alt_outlined
                                : Icons.refresh,
                          ),
                          label: Text(
                            enrolled == null
                                ? 'Open registration camera'
                                : 'Replace registration',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardTitle(
                        icon: Icons.center_focus_strong,
                        title: 'Live verification',
                        subtitle:
                            'Keep the camera open while results update automatically.',
                      ),
                      const SizedBox(height: 18),
                      _ActionTile(
                        icon: Icons.face_outlined,
                        title: 'Face recognition',
                        subtitle: 'Match the live face to the saved profile',
                        color: const Color(0xff246bfd),
                        enabled: ready && enrolled != null,
                        onTap: () => _openVerification(false),
                      ),
                      const SizedBox(height: 12),
                      _ActionTile(
                        icon: Icons.shield_outlined,
                        title: 'Liveness + recognition',
                        subtitle: 'Check for a live face before matching',
                        color: const Color(0xff11a985),
                        enabled: ready && enrolled != null,
                        onTap: () => _openVerification(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Color(0xff637487),
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Photos and templates never leave this device',
                        style: TextStyle(
                          color: Color(0xff637487),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    activationCode.dispose();
    sdk?.dispose();
    super.dispose();
  }
}

class EnrollmentCameraPage extends StatefulWidget {
  const EnrollmentCameraPage({super.key, required this.sdk, this.existingName});

  final MmlFaceSdk sdk;
  final String? existingName;

  @override
  State<EnrollmentCameraPage> createState() => _EnrollmentCameraPageState();
}

class _EnrollmentCameraPageState extends State<EnrollmentCameraPage> {
  CameraController? controller;
  CameraImage? latestFrame;
  String message = 'Position one face inside the guide';
  bool processing = false;
  bool cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      controller = await _createFrontCamera(ResolutionPreset.high);
      if (Platform.isAndroid) {
        await controller!.startImageStream((frame) {
          latestFrame = frame;
          if (mounted && !cameraReady) {
            setState(() {
              cameraReady = true;
              message = 'Position one face inside the guide';
            });
          }
        });
      } else if (mounted) {
        setState(() => cameraReady = true);
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Camera permission is required');
    }
  }

  Future<void> _capture() async {
    final camera = controller;
    if (!cameraReady || processing || camera == null) return;
    setState(() {
      processing = true;
      message = 'Checking face quality…';
    });
    try {
      final FaceTemplate template;
      if (Platform.isAndroid) {
        final frame = latestFrame;
        if (frame == null) throw StateError('Camera frame unavailable');
        template = await widget.sdk.createTemplateFromFrame(
          nv21: _mergeNv21(frame),
          width: frame.width,
          height: frame.height,
          rotationDegrees: _rotationDegrees(camera),
        );
      } else {
        final photo = await camera.takePicture();
        template = await widget.sdk.createTemplate(await photo.readAsBytes());
      }
      if (!mounted) return;
      final name = await _askForName(widget.existingName);
      if (name == null || !mounted) {
        setState(() {
          processing = false;
          message = 'Add a name to finish registration';
        });
        return;
      }
      Navigator.of(
        context,
      ).pop(EnrolledProfile(name: name, template: template));
    } on FaceSdkException catch (error) {
      if (!mounted) return;
      setState(() {
        processing = false;
        message = _friendlyError(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        processing = false;
        message = 'Could not capture the face. Please try again.';
      });
    }
  }

  Future<String?> _askForName(String? existing) async {
    final input = TextEditingController(
      text: existing == 'Enrolled user' ? '' : existing,
    );
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xff11a985),
            size: 42,
          ),
          title: const Text('Face captured'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a name for this local face profile.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: input,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Person name',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: error,
                ),
                onSubmitted: (_) {
                  final value = input.text.trim();
                  if (value.isEmpty) {
                    setDialogState(() => error = 'Please enter a name');
                  } else {
                    Navigator.pop(context, value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retake'),
            ),
            FilledButton(
              onPressed: () {
                final value = input.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = 'Please enter a name');
                } else {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) => _CameraShell(
    title: 'Register face',
    controller: controller,
    ready: cameraReady,
    guideColor: processing ? Colors.amber : const Color(0xff31e3c0),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: processing ? null : _capture,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: processing ? Colors.white24 : Colors.transparent,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: processing ? Colors.amber : const Color(0xff19c5b6),
              ),
              child: processing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Look straight · Good light · No glasses glare',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

class LiveVerificationPage extends StatefulWidget {
  const LiveVerificationPage({
    super.key,
    required this.sdk,
    required this.profile,
    required this.requireLiveness,
  });

  final MmlFaceSdk sdk;
  final EnrolledProfile profile;
  final bool requireLiveness;

  @override
  State<LiveVerificationPage> createState() => _LiveVerificationPageState();
}

class _LiveVerificationPageState extends State<LiveVerificationPage> {
  CameraController? controller;
  bool cameraReady = false;
  bool active = true;
  String message = 'Starting live camera…';
  Color statusColor = const Color(0xff31e3c0);
  double? similarity;
  double? liveness;
  double? distanceRatio;
  int livenessSamples = 0;
  bool processingFrame = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      controller = await _createFrontCamera(ResolutionPreset.medium);
      if (!mounted) return;
      setState(() {
        cameraReady = true;
        message = 'Place your face in front of the camera';
      });
      if (Platform.isAndroid) {
        await controller!.startImageStream((frame) {
          if (!active || processingFrame) {
            return;
          }
          processingFrame = true;
          unawaited(
            _processStreamFrame(
              frame,
            ).whenComplete(() => processingFrame = false),
          );
        });
      } else {
        unawaited(_scanLoop());
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Camera permission is required');
    }
  }

  Future<void> _processStreamFrame(CameraImage frame) async {
    final camera = controller;
    if (camera == null || !mounted || !active) return;
    try {
      final result = widget.requireLiveness
          ? await widget.sdk.verifyFrame(
              nv21: _mergeNv21(frame),
              width: frame.width,
              height: frame.height,
              rotationDegrees: _rotationDegrees(camera),
              template: widget.profile.template,
            )
          : await widget.sdk.recognizeFrame(
              nv21: _mergeNv21(frame),
              width: frame.width,
              height: frame.height,
              rotationDegrees: _rotationDegrees(camera),
              template: widget.profile.template,
            );
      if (!mounted || !active) return;
      await _applyResult(result);
    } on FaceSdkException catch (error) {
      _showFrameError(
        _friendlyError(error.code),
        distanceRatio: error.code == FaceSdkError.faceTooSmall ? .15 : null,
      );
    } catch (_) {
      _showFrameError('Camera frame unavailable — retrying…');
    }
  }

  Future<void> _scanLoop() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    while (mounted && active) {
      final camera = controller;
      if (camera == null || !camera.value.isInitialized) return;
      try {
        final photo = await camera.takePicture();
        final bytes = await photo.readAsBytes();
        final result = widget.requireLiveness
            ? await widget.sdk.verify(
                encodedImage: bytes,
                template: widget.profile.template,
              )
            : await widget.sdk.recognize(
                encodedImage: bytes,
                template: widget.profile.template,
              );
        if (!mounted || !active) return;
        if (await _applyResult(result)) return;
      } on FaceSdkException catch (error) {
        _showFrameError(
          _friendlyError(error.code),
          distanceRatio: error.code == FaceSdkError.faceTooSmall ? .15 : null,
        );
      } catch (_) {
        _showFrameError('Camera frame unavailable — retrying…');
      }
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  Future<bool> _applyResult(VerificationResult result) async {
    if (!mounted || !active) return true;
    similarity = result.similarity;
    liveness = result.livenessScore;
    if (!widget.requireLiveness) {
      if (result.matched) {
        await _showSuccess(result);
        return true;
      }
      final guidance = _distanceGuidance(
        result.quality.faceRatio,
        requiredRatio: .60,
      );
      setState(() {
        distanceRatio = guidance == null ? null : result.quality.faceRatio;
        message =
            guidance ?? 'Face not recognized — look directly at the camera';
        statusColor = const Color(0xffffb44b);
      });
    } else if (result.spoofLatched) {
      setState(() {
        distanceRatio = null;
        message = 'Spoof detected — present a live face';
        statusColor = const Color(0xffff5b6e);
        livenessSamples = 0;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await widget.sdk.resetLiveness();
    } else if (result.livenessPassed == true) {
      if (result.matched) {
        await _showSuccess(result);
        return true;
      }
      setState(() {
        distanceRatio = null;
        message = 'Live face confirmed, but not recognized';
        statusColor = const Color(0xffffb44b);
        livenessSamples = 0;
      });
      await widget.sdk.resetLiveness();
    } else if (result.livenessScore == null) {
      final guidance = _distanceGuidance(
        result.quality.faceRatio,
        requiredRatio: .72,
      );
      setState(() {
        distanceRatio = guidance == null ? null : result.quality.faceRatio;
        message = guidance ?? 'Hold still — checking liveness';
        statusColor = const Color(0xffffb44b);
      });
    } else {
      livenessSamples = math.min(4, livenessSamples + 1);
      setState(() {
        distanceRatio = null;
        message = livenessSamples < 4
            ? 'Checking liveness · $livenessSamples of 4'
            : 'Liveness not confirmed — keep a live face steady';
        statusColor = livenessSamples < 4
            ? const Color(0xff31e3c0)
            : const Color(0xffffb44b);
      });
    }
    return false;
  }

  void _showFrameError(String value, {double? distanceRatio}) {
    if (!mounted || !active) return;
    setState(() {
      this.distanceRatio = distanceRatio;
      message = value;
      statusColor = const Color(0xffffb44b);
    });
  }

  Future<void> _showSuccess(VerificationResult result) async {
    active = false;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => VerificationSuccessPage(
          name: widget.profile.name,
          livenessChecked: widget.requireLiveness,
          similarity: result.similarity,
          livenessScore: result.livenessScore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _CameraShell(
    title: widget.requireLiveness
        ? 'Liveness + recognition'
        : 'Face recognition',
    controller: controller,
    ready: cameraReady,
    guideColor: statusColor,
    showGuide: false,
    overlay: distanceRatio == null
        ? null
        : _DistancePrompt(
            message: message,
            progress: (distanceRatio! / (widget.requireLiveness ? .72 : .60))
                .clamp(0.0, 1.0),
          ),
    footer: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xdd091725),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withValues(alpha: .55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .22),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                child: child,
              ),
            ),
            child: Text(
              message,
              key: ValueKey(message),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: statusColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (similarity != null || liveness != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (similarity != null)
                  Expanded(
                    child: _Metric(
                      label: 'Similarity',
                      value: similarity!.toStringAsFixed(3),
                    ),
                  ),
                if (similarity != null && liveness != null)
                  const SizedBox(width: 10),
                if (liveness != null)
                  Expanded(
                    child: _Metric(
                      label: 'Liveness',
                      value: liveness!.toStringAsFixed(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  @override
  void dispose() {
    active = false;
    controller?.dispose();
    if (widget.requireLiveness) unawaited(widget.sdk.resetLiveness());
    super.dispose();
  }
}

class VerificationSuccessPage extends StatelessWidget {
  const VerificationSuccessPage({
    super.key,
    required this.name,
    required this.livenessChecked,
    required this.similarity,
    required this.livenessScore,
  });

  final String name;
  final bool livenessChecked;
  final double? similarity;
  final double? livenessScore;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffdff9f2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 64,
                color: Color(0xff0aaf82),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Welcome, $name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xff10283a),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              livenessChecked
                  ? 'Live face verified and identity recognized.'
                  : 'Face recognized successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xff637487)),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ResultValue(
                      label: 'Similarity',
                      value: similarity?.toStringAsFixed(3) ?? '—',
                    ),
                  ),
                  if (livenessChecked) ...[
                    Container(
                      width: 1,
                      height: 42,
                      color: const Color(0xffe5ebf0),
                    ),
                    Expanded(
                      child: _ResultValue(
                        label: 'Liveness',
                        value: livenessScore?.toStringAsFixed(3) ?? '—',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Return to home'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CameraShell extends StatelessWidget {
  const _CameraShell({
    required this.title,
    required this.controller,
    required this.ready,
    required this.guideColor,
    required this.footer,
    this.showGuide = true,
    this.overlay,
  });

  final String title;
  final CameraController? controller;
  final bool ready;
  final Color guideColor;
  final Widget footer;
  final bool showGuide;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff050d15),
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (ready && controller != null)
          _CoverCamera(controller: controller!)
        else
          const Center(
            child: CircularProgressIndicator(color: Color(0xff19c5b6)),
          ),
        if (ready && showGuide)
          IgnorePointer(
            child: CustomPaint(painter: _FaceGuidePainter(guideColor)),
          ),
        if (ready && overlay != null)
          Align(
            alignment: const Alignment(0, .12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: overlay,
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xaa07131f),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                footer,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DistancePrompt extends StatefulWidget {
  const _DistancePrompt({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  State<_DistancePrompt> createState() => _DistancePromptState();
}

class _DistancePromptState extends State<_DistancePrompt> {
  bool pulse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => pulse = true);
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    decoration: BoxDecoration(
      color: const Color(0xe60a1723),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: pulse ? 1.18 : .88,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
          onEnd: () {
            if (mounted) setState(() => pulse = !pulse);
          },
          child: const Icon(
            Icons.keyboard_double_arrow_up_rounded,
            color: Color(0xffffc34d),
            size: 46,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            widget.message,
            key: ValueKey(widget.message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: widget.progress),
            builder: (context, value, _) => LinearProgressIndicator(
              minHeight: 9,
              value: value,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xffffc34d)),
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Move toward the phone camera',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

class _CoverCamera extends StatelessWidget {
  const _CoverCamera({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize!;
    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .43),
      width: size.width * .68,
      height: size.height * .46,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(mask, Paint()..color = const Color(0x66030b12));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color;
    const length = 28.0;
    for (final point in [
      Offset(oval.left, oval.top),
      Offset(oval.right, oval.top),
      Offset(oval.left, oval.bottom),
      Offset(oval.right, oval.bottom),
    ]) {
      final left = point.dx == oval.left;
      final top = point.dy == oval.top;
      canvas.drawLine(
        point,
        point.translate(left ? length : -length, 0),
        cornerPaint,
      );
      canvas.drawLine(
        point,
        point.translate(0, top ? length : -length),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe5ebf0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0a10283a),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xffe5faf6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xff0a9f7a)),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xff10283a),
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Color(0xff637487))),
          ],
        ),
      ),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : .42,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xfff5f8fb),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff637487),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xff8b9aaa)),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ResultValue extends StatelessWidget {
  const _ResultValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Color(0xff637487))),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: Color(0xff10283a),
        ),
      ),
    ],
  );
}

Future<CameraController> _createFrontCamera(ResolutionPreset resolution) async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) throw StateError('No camera available');
  final description = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  final controller = CameraController(
    description,
    resolution,
    enableAudio: false,
    imageFormatGroup: Platform.isAndroid
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888,
  );
  await controller.initialize();
  await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
  return controller;
}

Uint8List _mergeNv21(CameraImage image) {
  final length = image.planes.fold<int>(
    0,
    (total, plane) => total + plane.bytes.length,
  );
  final bytes = Uint8List(length);
  var offset = 0;
  for (final plane in image.planes) {
    bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
    offset += plane.bytes.length;
  }
  return bytes;
}

int _rotationDegrees(CameraController controller) {
  const orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final deviceRotation = orientations[controller.value.deviceOrientation] ?? 0;
  final sensor = controller.description.sensorOrientation;
  return controller.description.lensDirection == CameraLensDirection.front
      ? (sensor + deviceRotation) % 360
      : (sensor - deviceRotation + 360) % 360;
}

String? _distanceGuidance(double faceRatio, {required double requiredRatio}) {
  if (faceRatio < .28) return 'Face detected — move much closer';
  if (faceRatio < .42) return 'Getting closer — keep moving toward camera';
  if (faceRatio < .58) return 'Good — move a little closer';
  if (faceRatio < requiredRatio) return 'Almost there — just a little closer';
  return null;
}

String _friendlyError(FaceSdkError error) => switch (error) {
  FaceSdkError.noFace => 'No face detected — look at the camera',
  FaceSdkError.multipleFaces => 'Only one face can be visible',
  FaceSdkError.faceTooSmall => 'Face detected — move much closer',
  FaceSdkError.faceNotFrontal => 'Look directly at the camera',
  FaceSdkError.landmarksMissing =>
    'Face details are unclear — improve lighting',
  FaceSdkError.poorQuality => 'Image quality is too low — improve lighting',
  FaceSdkError.spoofDetected => 'Spoof detected — present a live face',
  FaceSdkError.busy => 'Processing — hold still',
  FaceSdkError.licenseInvalid => 'SDK licence is not ready',
  _ => 'Face could not be processed — try again',
};
