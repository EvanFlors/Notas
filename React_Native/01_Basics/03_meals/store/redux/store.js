import { configureStore } from "@reduxjs/toolkit";
import mealsReducer from "./meals";

const store = configureStore({
  reducer: {
    meals: mealsReducer,
  },
});

export default store;
