import { useLayoutEffect } from "react";
import { useDispatch, useSelector } from "react-redux";

import { Image, ScrollView, StyleSheet, Text, View } from "react-native";

import MealDetail from "../components/MealDetail";
import List from "../components/MealDetail/List";
import Subtitle from "../components/MealDetail/Subtitle";

import IconButton from "../components/IconButton";
import { MEALS } from "../data/dummy-data";
import { addFavorite, removeFavorite } from "../store/redux/meals";

function MealDetailScreen({ route, navigation }) {
  const dispatch = useDispatch();
  const favoriteMealIds = useSelector((state) => state.meals.ids);

  const { mealId } = route.params;

  const selectedMeal = MEALS.find((meal) => meal.id === mealId);

  const mealIsFavorite = favoriteMealIds.includes(mealId);

  function headerButtonPressHandler() {
    if (mealIsFavorite) {
      dispatch(removeFavorite({ id: mealId }));
    } else {
      dispatch(addFavorite({ id: mealId }));
    }
  }

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => {
        return (
          <IconButton
            icon={mealIsFavorite ? "star" : "star-outline"}
            color="white"
            onPress={headerButtonPressHandler}
            size={24}
          />
        );
      },
    });
  }, [navigation, headerButtonPressHandler, mealIsFavorite]);

  return (
    <ScrollView style={styles.rootContainer}>
      <Image source={{ uri: selectedMeal.imageUrl }} style={styles.image} />
      <Text style={styles.title}>{selectedMeal.title}</Text>
      <MealDetail
        duration={selectedMeal.duration}
        complexity={selectedMeal.complexity}
        affordability={selectedMeal.affordability}
        textStyle={styles.detailText}
      />
      <View style={styles.listContainer}>
        <Subtitle>Ingredients</Subtitle>
        <List data={selectedMeal.ingredients} />
        <Subtitle>Steps</Subtitle>
        <List data={selectedMeal.steps} />
      </View>
    </ScrollView>
  );
}

export default MealDetailScreen;

const styles = StyleSheet.create({
  rootContainer: {
    marginBottom: 32,
  },
  image: {
    width: "100%",
    height: 350,
  },
  title: {
    fontWeight: "bold",
    fontSize: 24,
    margin: 8,
    textAlign: "center",
    color: "white",
  },
  detailText: {
    color: "white",
  },
  listContainer: {
    width: "80%",
    alignSelf: "center",
  },
});
