import { useContext, useEffect, useState } from "react";

import { StyleSheet, Text, View } from "react-native";

import { AuthContext } from "../store/auth";

import { fetchMessage } from "../util/http";

function WelcomeScreen() {
  const [fetchedMessage, setFetchedMessage] = useState("");

  const authCtx = useContext(AuthContext);
  const token = authCtx.token;

  useEffect(() => {
    async function getMessage() {
      try {
        const message = await fetchMessage(token);
        setFetchedMessage(message);
      } catch (error) {
        console.error(error);
      }
    }
    getMessage();
  }, [token]);

  return (
    <View style={styles.rootContainer}>
      <Text style={styles.title}>Welcome!</Text>
      <Text>You authenticated successfully!</Text>
      <Text>{fetchedMessage}</Text>
    </View>
  );
}

export default WelcomeScreen;

const styles = StyleSheet.create({
  rootContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 32,
  },
  title: {
    fontSize: 20,
    fontWeight: "bold",
    marginBottom: 8,
  },
});
