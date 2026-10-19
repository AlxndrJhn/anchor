import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/motion/springs.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../../core/widgets/form_page.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';
import '../domain/account_rules.dart';
import 'auth_controller.dart';
import 'auth_error_message.dart';

enum _Photo { take, choose, remove }

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with FormSubmit {
  final _name = TextEditingController();
  bool _isUploading = false;

  /// Hidden while Undo can still bring it back.
  bool _isPhotoPendingRemoval = false;

  /// The removal waiting for Undo to go.
  Object? _pendingRemoval;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(authControllerProvider).value?.name ?? '';
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _canSave(bool isOnline) {
    final name = _name.text.trim();
    return isOnline &&
        !isSubmitting() &&
        isNameValid(name) &&
        name != ref.read(authControllerProvider).value?.name;
  }

  Future<void> _save() => submit(
    () => ref.read(authControllerProvider.notifier).rename(_name.text.trim()),
    onSuccess: () => context.pop(),
    successMessage: context.l10n.profileSaved,
    onFailure: (error) =>
        showError(authErrorMessageOf(error, context.l10n).text),
  );

  Future<void> _changePhoto(bool hasPhoto) async {
    final l10n = context.l10n;
    final choice = await showChoiceSheet<_Photo>(
      context,
      title: l10n.profilePhoto,
      subtitle: l10n.profilePhotoVisible,
      choices: [
        SheetChoice(
          value: _Photo.take,
          icon: LucideIcons.camera,
          label: l10n.profileTakePhoto,
        ),
        SheetChoice(
          value: _Photo.choose,
          icon: LucideIcons.image,
          label: l10n.profileChoosePhoto,
        ),
        if (hasPhoto)
          SheetChoice(
            value: _Photo.remove,
            icon: LucideIcons.trash2,
            label: l10n.profileRemovePhoto,
            isDanger: true,
          ),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == _Photo.remove) return _removePhoto();
    final image = await ImagePicker().pickImage(
      source: choice == _Photo.take ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024, // off-scale: the picture's pixels, not layout
      maxHeight: 1024, // off-scale: as above
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    _pendingRemoval = null;
    setState(() {
      _isUploading = true;
      _isPhotoPendingRemoval = false;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .setPhoto(File(image.path));
      if (!mounted) return;
      AppSnackbar.show(
        context,
        context.l10n.profilePhotoUpdated,
        kind: SnackbarKind.success,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.profilePhotoUpdateFailed,
          kind: SnackbarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// The removal runs once Undo has gone, possibly after this page has closed.
  void _removePhoto() {
    final auth = ref.read(authControllerProvider.notifier);
    final removal = _pendingRemoval = Object();
    setState(() => _isPhotoPendingRemoval = true);
    AppSnackbar.show(
      context,
      context.l10n.profilePhotoRemoved,
      actionLabel: context.l10n.commonUndo,
      onAction: () {
        if (mounted) setState(() => _isPhotoPendingRemoval = false);
      },
      onClosed: (isUndone) async {
        if (isUndone || removal != _pendingRemoval) return;
        try {
          await auth.removePhoto();
        } catch (error) {
          AppLogger.instance.warn(
            LogTags.auth,
            'Removing the profile photo failed',
            error: error,
          );
          if (mounted) {
            AppSnackbar.show(
              context,
              context.l10n.profilePhotoRemoveFailed,
              kind: SnackbarKind.error,
            );
          }
        } finally {
          if (mounted) setState(() => _isPhotoPendingRemoval = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final isOnline = ref.watch(isOnlineProvider);
    final photo = _isPhotoPendingRemoval ? null : user?.profileImage;
    final density = context.density;
    final l10n = context.l10n;
    return FormPage(
      title: l10n.profileTitle,
      bottomBar: AppButton(
        label: l10n.commonSave,
        busyLabel: l10n.commonSaving,
        isBusy: isSubmitting(),
        hasShadow: true,
        onPressed: _canSave(isOnline) ? _save : null,
      ),
      children: [
        FormNotices(
          errorMessage: errorMessage,
          offlineText: l10n.profileOffline,
        ),
        Padding(
          padding: EdgeInsets.only(
            top: density.space8,
            bottom: AnchorTokens.space4,
          ),
          child: Center(
            child: _PhotoButton(
              name: user?.name ?? '?',
              photo: photo,
              isUploading: _isUploading,
              isEnabled: isOnline,
              onTap: isOnline && !_isUploading && user != null
                  ? () => _changePhoto(photo != null)
                  : null,
            ),
          ),
        ),
        SizedBox(height: density.space16),
        AppTextField(
          controller: _name,
          label: l10n.fieldName,
          enabled: isOnline,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_canSave(isOnline)) _save();
          },
        ),
        SizedBox(height: density.space16),
        AppTextField(
          label: l10n.fieldEmail,
          icon: LucideIcons.mail,
          readOnlyText: user?.email ?? '',
          help: l10n.profileEmailAdminOnly,
        ),
      ],
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.name,
    required this.photo,
    required this.isUploading,
    required this.isEnabled,
    required this.onTap,
  });

  final String name;
  final String? photo;
  final bool isUploading;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.thumb,
      onTap: onTap,
      semanticLabel: context.l10n.profileChangePhoto,
      child: SizedBox.square(
        dimension: PersonAvatar.profile,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: isUploading ? 0.6 : 1,
              duration: context.motion(AnchorTokens.motionDurationFade),
              child: PersonAvatar(
                name: name,
                imageUrl: photo,
                size: PersonAvatar.profile,
              ),
            ),
            if (isUploading)
              Positioned.fill(
                left: -_UploadRing.gap,
                top: -_UploadRing.gap,
                right: -_UploadRing.gap,
                bottom: -_UploadRing.gap,
                child: _UploadRing(color: colors.accentStrong),
              ),
            Positioned(
              right: 0,
              bottom: 2, // off-scale: on the picture's edge
              child: Opacity(
                opacity: isEnabled ? 1 : DisabledOpacity.button,
                child: Container(
                  width: AnchorTokens.sizeControlSmall,
                  height: AnchorTokens.sizeControlSmall,
                  decoration: BoxDecoration(
                    color: colors.appInverse,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.appPage, width: 3),
                    boxShadow: colors.shadowSm,
                  ),
                  child: Icon(
                    LucideIcons.camera,
                    size: AnchorTokens.sizeIconSmall,
                    color: colors.appOnInverse,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadRing extends StatefulWidget {
  const _UploadRing({required this.color});

  static const double gap = 5; // off-scale: ring
  static const double width = 3; // off-scale: ring
  static const double size = PersonAvatar.profile + 2 * gap;

  final Color color;

  @override
  State<_UploadRing> createState() => _UploadRingState();
}

class _UploadRingState extends State<_UploadRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: AnchorTokens.motionDurationSpin,
  )..repeat();

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _turns,
    child: CustomPaint(
      size: const Size.square(_UploadRing.size),
      painter: _RingPainter(widget.color),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = (Offset.zero & size).deflate(_UploadRing.width / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _UploadRing.width;
    canvas.drawArc(
      ring,
      0,
      2 * math.pi,
      false,
      stroke..color = color.withValues(alpha: 0.22),
    );
    canvas.drawArc(
      ring,
      -0.75 * math.pi,
      0.5 * math.pi,
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
