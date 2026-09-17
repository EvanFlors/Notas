import { createContext, useState } from "react";

export const AuthContext = createContext({
  token: "",
  isAuthenticated: false,
  authenticate: (token) => {},
  logout: () => {},
});

function AuthContextProvider({ children }) {
  const [token, setToken] = useState();

  function authenticate(token) {
    setToken(token);
  }

  function logout() {
    setToken(null);
  }

  const value = {
    token: token,
    isAuthenticated: !!token,
    authenticate: authenticate,
    logout: logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export default AuthContextProvider;
