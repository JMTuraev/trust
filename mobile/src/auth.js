import React, { createContext, useContext, useState, useEffect } from 'react';
import * as SecureStore from 'expo-secure-store';
import { api } from './api';

const AuthContext = createContext(null);
const KEY = 'trust_session';

export function AuthProvider({ children }) {
  const [token, setToken] = useState(null);
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const raw = await SecureStore.getItemAsync(KEY);
        if (raw) {
          const s = JSON.parse(raw);
          setToken(s.token);
          setUser(s.user);
        }
      } catch {}
      setReady(true);
    })();
  }, []);

  const signIn = async (token, user) => {
    setToken(token);
    setUser(user);
    await SecureStore.setItemAsync(KEY, JSON.stringify({ token, user }));
  };

  const signOut = async () => {
    setToken(null);
    setUser(null);
    await SecureStore.deleteItemAsync(KEY);
  };

  return (
    <AuthContext.Provider value={{ token, user, ready, signIn, signOut, api }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
