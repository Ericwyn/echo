import 'package:echoes/data/models/music_library.dart';
import 'package:echoes/core/utils/logger.dart';
import 'package:echoes/data/repositories/auth_repository.dart';
import 'package:echoes/data/repositories/library_repository.dart';

import 'package:echoes/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 认证仓库 Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// 认证状态 Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final libraryRepository = ref.watch(libraryRepositoryProvider);
  return AuthNotifier(repository, libraryRepository);
});

/// 认证状态
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isInitializing;
  final MusicLibrary? currentLibrary;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isInitializing = true,
    this.currentLibrary,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isInitializing,
    MusicLibrary? currentLibrary,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      currentLibrary: currentLibrary ?? this.currentLibrary,
      errorMessage: errorMessage,
    );
  }
}

/// 认证状态管理器
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final LibraryRepository _libraryRepository;
  late final Future<void> initialized;

  AuthNotifier(this._repository, this._libraryRepository) : super(AuthState()) {
    initialized = _init();
  }

  /// 初始化：加载活跃的 Library
  Future<void> _init() async {
    Logger.infoWithTag('AUTH', 'auth state init start');
    state = state.copyWith(isLoading: true);

    try {
      final libraries = await _libraryRepository.watchLibraries().first;
      final active = libraries.where((l) => l.isActive).firstOrNull;
      if (active != null) {
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isInitializing: false,
          currentLibrary: active,
        );
        Logger.infoWithTag(
          'AUTH',
          'auth state init success, active library=${active.name}',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isInitializing: false,
          isAuthenticated: false,
        );
        Logger.warnWithTag('AUTH', 'auth state init: no active library');
      }
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        isAuthenticated: false,
      );
      Logger.errorWithTag('AUTH', 'auth state init failed', e, stackTrace);
    }
  }

  /// 使用密码登录
  Future<bool> loginWithPassword({
    required String serverUrl,
    required String username,
    required String password,
    String? libraryName,
    String? addressLabel,
    Future<void> Function()? beforeActivateLibrary,
    Future<void> Function()? onActivationFailed,
  }) async {
    Logger.infoWithTag('AUTH', 'password login started');
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _repository.loginWithPassword(
        serverUrl: serverUrl,
        username: username,
        password: password,
        libraryName: libraryName,
        addressLabel: addressLabel,
      );

      return _handleLoginResult(
        result,
        beforeActivateLibrary: beforeActivateLibrary,
        onActivationFailed: onActivationFailed,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '连接服务器失败，请检查网络后重试',
      );
      Logger.errorWithTag(
        'AUTH',
        'password login request failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  /// 使用 API Key 登录
  Future<bool> loginWithApiKey({
    required String serverUrl,
    required String username,
    required String apiKey,
    String? libraryName,
    String? addressLabel,
    Future<void> Function()? beforeActivateLibrary,
    Future<void> Function()? onActivationFailed,
  }) async {
    Logger.infoWithTag('AUTH', 'API key login started');
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _repository.loginWithApiKey(
        serverUrl: serverUrl,
        username: username,
        apiKey: apiKey,
        libraryName: libraryName,
        addressLabel: addressLabel,
      );

      return _handleLoginResult(
        result,
        beforeActivateLibrary: beforeActivateLibrary,
        onActivationFailed: onActivationFailed,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '连接服务器失败，请检查网络后重试',
      );
      Logger.errorWithTag(
        'AUTH',
        'API key login request failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> _handleLoginResult(
    LoginResult result, {
    Future<void> Function()? beforeActivateLibrary,
    Future<void> Function()? onActivationFailed,
  }) async {
    if (result.success && result.library != null) {
      var librarySaved = false;
      try {
        await beforeActivateLibrary?.call();
        final savedLibrary = result.library!.copyWith(isActive: false);
        await _libraryRepository.addLibrary(savedLibrary);
        librarySaved = true;
        await _libraryRepository.setActiveLibrary(result.library!.id);

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          currentLibrary: result.library!,
        );
        Logger.infoWithTag('AUTH', 'login succeeded');

        return true;
      } catch (error, stackTrace) {
        if (librarySaved) {
          try {
            await _libraryRepository.deleteLibrary(result.library!.id);
          } catch (cleanupError, cleanupStackTrace) {
            Logger.errorWithTag(
              'AUTH',
              'failed to remove inactive library after activation failure',
              cleanupError,
              cleanupStackTrace,
            );
          }
        }
        try {
          await onActivationFailed?.call();
        } catch (rollbackError, rollbackStackTrace) {
          Logger.errorWithTag(
            'AUTH',
            'failed to restore playback after library activation failure',
            rollbackError,
            rollbackStackTrace,
          );
        }
        state = state.copyWith(
          isLoading: false,
          errorMessage: '保存或切换音乐库失败，请重试',
        );
        Logger.errorWithTag(
          'AUTH',
          'library activation failed',
          error,
          stackTrace,
        );
        return false;
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      Logger.warnWithTag('AUTH', 'login failed');
      return false;
    }
  }

  /// 登出（停用当前 Library，保留记录以便重新登录）
  Future<void> logout() async {
    Logger.infoWithTag('AUTH', 'logout start');

    if (state.currentLibrary != null) {
      try {
        await _libraryRepository.setActiveLibrary('');
      } catch (e, stackTrace) {
        Logger.errorWithTag(
          'AUTH',
          'failed to clear active library',
          e,
          stackTrace,
        );
      }
    }

    state = AuthState(isAuthenticated: false);
    Logger.infoWithTag('AUTH', 'logout completed');
  }

  /// 切换当前 Library
  void switchLibrary(MusicLibrary library) {
    Logger.infoWithTag('AUTH', 'switchLibrary: ${library.name}');
    state = state.copyWith(currentLibrary: library, isAuthenticated: true);
  }

  /// 清除错误消息
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
