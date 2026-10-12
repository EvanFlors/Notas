import { useSelector } from "react-redux";
import { StyleSheet, Text, View } from "react-native";

import MealsList from "../components/MealList/MealsList";
import { MEALS } from "../data/dummy-data";

function FavoritesScreen() {
  const favoriteMealIds = useSelector((state) => state.meals.ids);

  const favoriteMeals = MEALS.filter((meal) =>
    favoriteMealIds.includes(meal.id)
  );

  if (favoriteMeals.length === 0) {
    return (
      <View style={styles.rootContainer}>
        <Text style={styles.text}>You have no favorite meals yet.</Text>
      </View>
    );
  }

  return (
    <View style={styles.rootContainer}>
      <MealsList items={favoriteMeals} />
    </View>
  );
}

export default FavoritesScreen;

const styles = StyleSheet.create({
  rootContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  text: {
    color: "white",
    fontSize: 16,
  },
});
