import { useContext } from "react";

import ExpensesOutput from "../components/ExpensesOutput/ExpensesOutput";

import { ExpensesContext } from "../store/expenses-context";

function AllExpenses() {
  const expensesCtx = useContext(ExpensesContext);

  return (
    <ExpensesOutput
      expenses={expensesCtx.expenses}
      periodName="Total"
      fallbackText="No expenses registered yet!"
    />
  );
}

export default AllExpenses;
