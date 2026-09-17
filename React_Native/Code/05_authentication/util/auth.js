import axios from "axios";

const API_KEY = "AIzaSyCCO9yZgvVxevy_68vQ9gFJHXUWowOzQhk";

async function authenticate(mode, email, password) {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:${mode}?key=${API_KEY}`;

  const response = await axios.post(url, {
    email: email,
    password: password,
    returnSecureToken: true,
  });

  const token = response.data.idToken;
  return token;
}

async function createUser(email, password) {
  return authenticate("signUp", email, password);
}

async function login(email, password) {
  return authenticate("signInWithPassword", email, password);
}

export { createUser, login };
