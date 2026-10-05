import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import { ActivityIndicator, StyleSheet, View } from "react-native";

import AddPlace from "./screens/AddPlace";
import AllPlaces from "./screens/AllPlaces";
import Map from "./screens/Map";
import PlaceDetails from "./screens/PlaceDetails";

import { init } from "./util/database";

import { Colors } from "./constants/styles";

import IconButton from "./components/UI/IconButton";

const Stack = createNativeStackNavigator();

export default function App() {
  const [dbInitialized, setDbInitialized] = useState(false);

  useEffect(() => {
    init()
      .then(() => {
        console.log("Initialized database");
        setDbInitialized(true);
      })
      .catch((err) => {
        console.log("Initializing db failed.");
        console.log(err);
      });
  }, []);

  if (!dbInitialized) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color={Colors.primary500} />
      </View>
    );
  }

  return (
    <>
      <StatusBar style="auto" />
      <NavigationContainer>
        <Stack.Navigator
          screenOptions={{
            headerStyle: { backgroundColor: Colors.primary500 },
            headerTintColor: Colors.gray700,
            contentStyle: { backgroundColor: Colors.primary100 },
          }}
        >
          <Stack.Screen
            name="AllPlaces"
            component={AllPlaces}
            options={({ navigation }) => ({
              title: "Your Favorite Places",
              headerRight: ({ tintColor }) => (
                <IconButton
                  icon="add"
                  size={24}
                  color={tintColor}
                  onPress={() => navigation.navigate("AddPlace")}
                />
              ),
            })}
          />
          <Stack.Screen
            name="AddPlace"
            component={AddPlace}
            options={{ title: "Add a new place", headerBackTitle: "Back" }}
          />
          <Stack.Screen name="Map" component={Map} options={{ title: "Map" }} />
          <Stack.Screen
            name="PlaceDetails"
            component={PlaceDetails}
            options={{ title: "Loading place..." }}
          />
        </Stack.Navigator>
      </NavigationContainer>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center",
  },
});
