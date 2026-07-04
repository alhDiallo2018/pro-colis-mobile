import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/providers/auth_provider.dart';

User _testUser({String fullName = 'John Doe'}) {
  return User(
    id: 'user-001',
    email: 'test@test.com',
    phone: '+221771234567',
    fullName: fullName,
    role: UserRole.client,
    status: UserStatus.active,
  );
}

void main() {
  group('AuthState', () {
    test('initial state is unauthenticated', () {
      final state = AuthState.initial();

      expect(state.isLoading, false);
      expect(state.isAuthenticated, false);
      expect(state.user, null);
      expect(state.error, null);
    });

    test('loading state has isLoading true', () {
      final state = AuthState.loading();

      expect(state.isLoading, true);
      expect(state.isAuthenticated, false);
    });

    test('authenticated state has user and isAuthenticated', () {
      final user = _testUser();
      final state = AuthState.authenticated(user);

      expect(state.isLoading, false);
      expect(state.isAuthenticated, true);
      expect(state.user, user);
      expect(state.error, null);
    });

    test('error state has error message', () {
      final state = AuthState.error('Invalid PIN');

      expect(state.isLoading, false);
      expect(state.isAuthenticated, false);
      expect(state.error, 'Invalid PIN');
    });

    test('copyWith preserves fields and overrides specified ones', () {
      final original = AuthState.initial();

      final modified = original.copyWith(isLoading: true);

      expect(modified.isLoading, true);
      expect(modified.isAuthenticated, false);
      expect(original.isLoading, false);
    });

    test('displayName returns first name', () {
      final user = _testUser(fullName: 'Aminata Diop');
      final state = AuthState.authenticated(user);

      expect(state.displayName, 'Aminata');
    });

    test('displayName returns fallback for null user', () {
      final state = AuthState.initial();

      expect(state.displayName, 'Utilisateur');
    });
  });

  group('AuthProvider', () {
    test('creates provider with initial unauthenticated state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authProvider);

      expect(state.isLoading, false);
      expect(state.isAuthenticated, false);
      expect(state.user, null);
    });
  });
}
