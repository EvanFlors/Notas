import { useState } from "react";
import { StyleSheet, Text, View } from "react-native";

import Button from "../UI/Button";
import Input from "./Input";

import { getFormattedDate } from "../../util/date";

function ExpenseForm({ onCancel, onSubmit, submitButtonLabel, defaultValues }) {
  const [inputs, setInputs] = useState({
    amount: {
      value: defaultValues ? defaultValues.amount.toString() : "",
      isValid: true,
    },
    date: {
      value: defaultValues ? getFormattedDate(defaultValues.date) : "",
      isValid: true,
    },
    description: {
      value: defaultValues ? defaultValues.description : "",
      isValid: true,
    },
  });

  function inputChangedHandler(inputIdentifier, enteredValue) {
    setInputs((currentInputValues) => {
      return {
        ...currentInputValues,
        [inputIdentifier]: { value: enteredValue, isValid: true },
      };
    });
  }

  function submitHandler() {
    const expenseData = {
      amount: +inputs.amount.value,
      date: new Date(inputs.date.value),
      description: inputs.description.value,
    };

    const amountIsValid = !isNaN(expenseData.amount) && expenseData.amount > 0;
    const dateIsValid = expenseData.date.toString() !== "Invalid Date";
    const descriptionIsValid = expenseData.description.trim().length > 0;

    if (!amountIsValid || !dateIsValid || !descriptionIsValid) {
      setInputs((currentInputValues) => {
        return {
          amount: {
            value: currentInputValues.amount.value,
            isValid: amountIsValid,
          },
          date: { value: currentInputValues.date.value, isValid: dateIsValid },
          description: {
            value: currentInputValues.description.value,
            isValid: descriptionIsValid,
          },
        };
      });
      return;
    }

    onSubmit(expenseData);
  }

  const formIsInvalid =
    !inputs.amount.isValid ||
    !inputs.date.isValid ||
    !inputs.description.isValid;

  return (
    <View style={styles.form}>
      <Text style={styles.title}>Your Expense</Text>
      <View style={styles.inputsRow}>
        <Input
          label="Amount"
          textInputConfig={{ keyboardType: "decimal-pad" }}
          onChangeText={(enteredValue) =>
            inputChangedHandler("amount", enteredValue)
          }
          style={styles.rowInput}
          value={inputs.amount.value}
          invalid={!inputs.amount.isValid}
          // onChangeText={(enteredValue) =>
          //   setInputValues((currentInputValues) => {
          //     return { ...currentInputValues, amount: enteredValue };
          //   })
          // }
        />
        <Input
          label="Date"
          textInputConfig={{ placeholder: "YYYY-MM-DD" }}
          style={styles.rowInput}
          value={inputs.date.value}
          onChangeText={(enteredValue) =>
            inputChangedHandler("date", enteredValue)
          }
          invalid={!inputs.date.isValid}
        />
      </View>
      <Input
        label="Description"
        textInputConfig={{ multiline: true, autoCorrect: false }}
        value={inputs.description.value}
        onChangeText={(enteredValue) =>
          inputChangedHandler("description", enteredValue)
        }
        invalid={!inputs.description.isValid}
      />
      {formIsInvalid && (
        <Text style={styles.errorText}>
          Invalid input values - please check your entered data!
        </Text>
      )}
      <View style={styles.buttonsContainer}>
        <Button onPress={onCancel} mode="flat" style={styles.button}>
          Cancel
        </Button>
        <Button onPress={submitHandler} style={styles.button}>
          {submitButtonLabel}
        </Button>
      </View>
    </View>
  );
}

export default ExpenseForm;

const styles = StyleSheet.create({
  form: {
    marginTop: 40,
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    color: "white",
    marginVertical: 24,
    textAlign: "center",
  },
  inputsRow: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  rowInput: {
    flex: 1,
  },
  buttonsContainer: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
  },
  button: {
    minWidth: 120,
    marginHorizontal: 8,
  },
  errorText: {
    textAlign: "center",
    color: "red",
    marginVertical: 8,
  },
});
