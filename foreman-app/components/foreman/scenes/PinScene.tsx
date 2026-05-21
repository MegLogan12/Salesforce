import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
  Platform,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

const PIN_LENGTH = 4;

const KEYPAD: string[][] = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
  ['', '0', '⌫'],
];

export function PinScene() {
  const pinEntered = useForeman(s => s.pinEntered);
  const pinAuth = useForeman(s => s.pinAuth);
  const appendPinDigit = useForeman(s => s.appendPinDigit);
  const backspacePin = useForeman(s => s.backspacePin);
  const submitPin = useForeman(s => s.submitPin);

  const shakeAnim = useRef(new Animated.Value(0)).current;
  const dotAnims = useRef(Array.from({ length: PIN_LENGTH }, () => new Animated.Value(0))).current;

  // Auto-submit when PIN_LENGTH digits entered
  useEffect(() => {
    if (pinEntered.length === PIN_LENGTH) {
      const ok = submitPin();
      if (!ok) {
        // Shake animation on wrong PIN
        Animated.sequence([
          Animated.timing(shakeAnim, { toValue: 10, duration: 60, useNativeDriver: true }),
          Animated.timing(shakeAnim, { toValue: -10, duration: 60, useNativeDriver: true }),
          Animated.timing(shakeAnim, { toValue: 10, duration: 60, useNativeDriver: true }),
          Animated.timing(shakeAnim, { toValue: -10, duration: 60, useNativeDriver: true }),
          Animated.timing(shakeAnim, { toValue: 0, duration: 60, useNativeDriver: true }),
        ]).start();
      }
    }
  }, [pinEntered]);

  // Animate dot fill when digit entered
  useEffect(() => {
    dotAnims.forEach((anim, idx) => {
      Animated.timing(anim, {
        toValue: idx < pinEntered.length ? 1 : 0,
        duration: 120,
        useNativeDriver: false,
      }).start();
    });
  }, [pinEntered]);

  function handleKey(key: string) {
    if (key === '⌫') {
      backspacePin();
    } else if (key !== '') {
      appendPinDigit(key);
    }
  }

  if (pinAuth.locked) {
    return (
      <View style={styles.root}>
        <View style={styles.lockCard}>
          <Text style={styles.lockIcon}>🔒</Text>
          <Text style={styles.lockTitle}>Account Locked</Text>
          <Text style={styles.lockSub}>Contact your Field Manager to unlock</Text>
          <View style={styles.lockContact}>
            <Text style={styles.lockContactText}>📞 Avery Solano  ·  +1 (469) 555-0182</Text>
          </View>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      {/* Logo */}
      <View style={styles.logoArea}>
        <Text style={styles.logoText}>LOVING</Text>
        <Text style={styles.logoSub}>Field App</Text>
      </View>

      {/* PIN prompt */}
      <Text style={styles.prompt}>Enter PIN</Text>

      {/* Attempts warning */}
      {pinAuth.attemptsRemaining < 5 && (
        <Text style={styles.attemptsWarning}>
          {pinAuth.attemptsRemaining} attempt{pinAuth.attemptsRemaining !== 1 ? 's' : ''} remaining
        </Text>
      )}

      {/* Dot indicators */}
      <Animated.View style={[styles.dotsRow, { transform: [{ translateX: shakeAnim }] }]}>
        {dotAnims.map((anim, idx) => {
          const bg = anim.interpolate({ inputRange: [0, 1], outputRange: ['rgba(255,255,255,0.25)', C.white] });
          const scale = anim.interpolate({ inputRange: [0, 1], outputRange: [1, 1.15] });
          return (
            <Animated.View
              key={idx}
              style={[styles.dot, { backgroundColor: bg, transform: [{ scale }] }]}
            />
          );
        })}
      </Animated.View>

      {/* Keypad */}
      <View style={styles.keypad}>
        {KEYPAD.map((row, ri) => (
          <View key={ri} style={styles.keyRow}>
            {row.map((key, ki) => (
              <TouchableOpacity
                key={ki}
                style={[styles.keyBtn, key === '' && styles.keyBtnEmpty]}
                onPress={() => handleKey(key)}
                activeOpacity={key === '' ? 1 : 0.65}
                disabled={key === '' || pinEntered.length >= PIN_LENGTH}
              >
                <Text style={[styles.keyText, key === '⌫' && styles.deleteText]}>{key}</Text>
              </TouchableOpacity>
            ))}
          </View>
        ))}
      </View>

      <Text style={styles.hint}>PIN: 1421 (demo)</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: C.navy,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  logoArea: { alignItems: 'center', marginBottom: 40 },
  logoText: {
    fontSize: 42,
    fontWeight: '900',
    color: C.white,
    letterSpacing: 6,
  },
  logoSub: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.5)',
    letterSpacing: 3,
    marginTop: 4,
    textTransform: 'uppercase',
  },
  prompt: {
    fontSize: 16,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.8)',
    marginBottom: 8,
    letterSpacing: 0.5,
  },
  attemptsWarning: {
    fontSize: 12,
    color: C.orange,
    fontWeight: '600',
    marginBottom: 12,
  },
  dotsRow: {
    flexDirection: 'row',
    gap: 18,
    marginVertical: 28,
  },
  dot: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.5)',
  },
  keypad: { width: '100%', maxWidth: 280, gap: 12 },
  keyRow: { flexDirection: 'row', justifyContent: 'center', gap: 12 },
  keyBtn: {
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  keyBtnEmpty: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  keyText: {
    fontSize: 26,
    fontWeight: '400',
    color: C.white,
  },
  deleteText: {
    fontSize: 22,
    color: 'rgba(255,255,255,0.7)',
  },
  hint: {
    marginTop: 32,
    fontSize: 11,
    color: 'rgba(255,255,255,0.3)',
  },
  lockCard: {
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: 16,
    padding: 32,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    maxWidth: 320,
    width: '100%',
  },
  lockIcon: { fontSize: 48, marginBottom: 16 },
  lockTitle: { fontSize: 22, fontWeight: '700', color: C.white, marginBottom: 8 },
  lockSub: { fontSize: 14, color: 'rgba(255,255,255,0.6)', textAlign: 'center', marginBottom: 20 },
  lockContact: {
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  lockContactText: { fontSize: 13, color: 'rgba(255,255,255,0.75)', fontWeight: '500' },
});
