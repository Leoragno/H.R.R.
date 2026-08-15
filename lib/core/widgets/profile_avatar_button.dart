import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';

/// Avatar utente cliccabile, apre il Profilo. Prende il posto del tab
/// "Profilo" nella bottom navbar (rimosso): unico punto d'accesso rimasto,
/// replicato nell'header delle 4 tab principali.
class ProfileAvatarButton extends ConsumerWidget {
  final double size;

  const ProfileAvatarButton({super.key, this.size = 46});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(myProfileProvider).valueOrNull?.avatarUrl;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.profile),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColor.surfaceHigh,
        ),
        child: avatarUrl == null
            ? Icon(Icons.person_rounded,
                color: AppColor.inkMuted, size: size * 0.52)
            : ClipOval(
                child: Image.network(avatarUrl, fit: BoxFit.cover),
              ),
      ),
    );
  }
}
