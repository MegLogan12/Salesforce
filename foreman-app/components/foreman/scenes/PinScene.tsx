import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

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

  useEffect(() => {
    if (pinEntered.length === PIN_LENGTH) {
      const ok = submitPin();
      if (!ok) {
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
      <View style={styles.logoArea}>
        <View style={styles.logoMark}>
          <Text style={styles.logoMarkText}>L</Text>
        </View>
        <Text style={styles.logoText}>LOVING</Text>
        <Text style={styles.logoSub}>FIELD APP</Text>
      </View>

      <Text style={styles.prompt}>Enter your PIN to continue</Text>

      {pinAuth.attemptsRemaining < 5 && (
        <Text style={styles.attemptsWarning}>
          {pinAuth.attemptsRemaining} attempt{pinAuth.attemptsRemaining !== 1 ? 's' : ''} remaining
        </Text>
      )}

      <Animated.View style={[styles.dotsRow, { transform: [{ translateX: shakeAnim }] }]}>
        {dotAnims.map((anim, idx) => {
          const bg = anim.interpolate({ inputRange: [0, 1], outputRange: ['rgba(255,255,255,0.18)', C.white] });
          const scale = anim.interpolate({ inputRange: [0, 1], outputRange: [1, 1.15] });
          return (
            <Animated.View
              key={idx}
              style={[styles.dot, { backgroundColor: bg, transform: [{ scale }] }]}
            />
          );
        })}
      </Animated.View>

      <View style={styles.keypad}>
        {KEYPAD.map((row, ri) => (
          <View key={ri} style={styles.keyRow}>
            {row.map((key, ki) => (
              <TouchableOpacity
                key={ki}
                style={[styles.keyBtn, key === '' && styles.keyBtnEmpty]}
                onPress={() => handleKey(key)}
                activeOpacity={key === '' ? 1 : 0.6}
                disabled={key === '' || pinEntered.length >= PIN_LENGTH}
              >
                <Text style={[styles.keyText, key === '⌫' && styles.deleteText]}>{key}</Text>
              </TouchableOpacity>
            ))}
          </View>
        ))}
      </View>

      <View style={styles.sfFooter}>
        <View style={styles.sfFooterDot} />
        <Text style={styles.sfFooterText}>Salesforce Connected · LOVING Production</Text>
      </View>
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
  logoArea: { alignItems: 'center', marginBottom: 44 },
  logoMark: {
    width: 56,
    height: 56,
    borderRadius: 16,
    backgroundColor: C.blue,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 14,
    ...Sh.md,
  },
  logoMarkText: { fontSize: 28, fontWeight: '900', color: C.white },
  logoText: {
    fontSize: 36,
    fontWeight: '900',
    color: C.white,
    letterSpacing: 7,
  },
  logoSub: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.4)',
    letterSpacing: 3.5,
    marginTop: 5,
    textTransform: 'uppercase',
  },
  prompt: {
    fontSize: 15,
    fontWeight: '500',
    color: 'rgba(255,255,255,0.65)',
    marginBottom: 6,
    letterSpacing: 0.3,
  },
  attemptsWarning: {
    fontSize: 12,
    color: C.orange,
    fontWeight: '700',
    marginBottom: 10,
  },
  dotsRow: {
    flexDirection: 'row',
    gap: 20,
    marginVertical: 30,
  },
  dot: {
    width: 17,
    height: 17,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.4)',
  },
  keypad: { width: '100%', maxWidth: 288, gap: 12 },
  keyRow: { flexDirection: 'row', justifyContent: 'center', gap: 12 },
  keyBtn: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.16)',
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
    color: 'rgba(255,255,255,0.65)',
  },
  sfFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 40,
    opacity: 0.55,
  },
  sfFooterDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: C.green },
  sfFooterText: { fontSize: 11, color: 'rgba(255,255,255,0.7)', fontWeight: '500' },
  lockCard: {
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: R.lg,
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
    borderRadius: R.sm,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  lockContactText: { fontSize: 13, color: 'rgba(255,255,255,0.75)', fontWeight: '500' },
});
