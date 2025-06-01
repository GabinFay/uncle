"use client";

import LoanStatusScreen from "@/components/uncle/screens/loan-status-screen";
import LoanApplication from "@/components/uncle/screens/loan-application";
import CommunityVouchingScreen from "@/components/uncle/screens/community-vouching-screen";
import { useState } from "react";

interface Voucher {
  name: string;
  amount: number;
  avatarUrl?: string;
  message?: string; // Optional message from voucher
}

type ScreenState = "LOAN_APPLICATION" | "LOAN_STATUS" | "COMMUNITY_VOUCHING";

export default function HomePage() { // Renamed from Page to HomePage
  const [currentScreen, setCurrentScreen] =
    useState<ScreenState>("LOAN_APPLICATION");

  const [userLoanDetails, setUserLoanDetails] = useState({
    borrowerName: "You",
    amount: 100,
    purpose: "work equipment",
    fundedAmount: 0,
    vouchers: [] as Voucher[],
    score: 0,
    repaymentDays: 3,
    paymentDueDate: new Date(new Date().setDate(new Date().getDate() + 3)), // Default to 3 days from now
  });

  const [currentUserAppScore, setCurrentUserAppScore] = useState(0);

  const handleLoanSubmitted = (amount: number, purpose: string) => {
    const dueDate = new Date();
    dueDate.setDate(dueDate.getDate() + userLoanDetails.repaymentDays); // Use repaymentDays from state

    setUserLoanDetails({
      borrowerName: "You",
      amount,
      purpose,
      fundedAmount: 0,
      vouchers: [],
      score: 0, // Initial score for a new loan
      repaymentDays: userLoanDetails.repaymentDays, // Keep existing or set new default
      paymentDueDate: dueDate,
    });
    setCurrentUserAppScore((prevScore) => prevScore + 5); // User's app score might increase
    setCurrentScreen("LOAN_STATUS");
  };

  const handleAskForNewLoan = () => {
    const defaultDueDate = new Date();
    defaultDueDate.setDate(defaultDueDate.getDate() + 3);
    setUserLoanDetails({
      // Reset to a default new loan state
      borrowerName: "You",
      amount: 100, // Default or last used
      purpose: "new goal", // Default or last used
      fundedAmount: 0,
      vouchers: [],
      score: currentUserAppScore, // Keep current user's app score
      repaymentDays: 3,
      paymentDueDate: defaultDueDate,
    });
    setCurrentScreen("LOAN_APPLICATION");
  };

  const handleShareUserLoanToVouchingView = () => {
    setCurrentScreen("COMMUNITY_VOUCHING");
  };

  const handleVouchAction = (
    borrowerName: string,
    vouchedAmount: number,
    message: string
  ) => {
    if (borrowerName === userLoanDetails.borrowerName) {
      setUserLoanDetails((prevDetails) => {
        const newFundedAmount = prevDetails.fundedAmount + vouchedAmount;
        const isNowFullyFunded = newFundedAmount >= prevDetails.amount;

        let newPaymentDueDate = prevDetails.paymentDueDate;
        if (isNowFullyFunded && prevDetails.fundedAmount < prevDetails.amount) {
          // If it JUST became fully funded, set due date to today
          newPaymentDueDate = new Date();
        }

        const newVoucher: Voucher = {
          name: `Friend (Score ${currentUserAppScore})`,
          amount: vouchedAmount,
          message: message || undefined,
          avatarUrl: "/placeholder.svg?height=24&width=24", // This will need to be in my-mini-app2/public
        };
        return {
          ...prevDetails,
          fundedAmount: Math.min(newFundedAmount, prevDetails.amount),
          vouchers: [...prevDetails.vouchers, newVoucher],
          score: prevDetails.score + vouchedAmount + (isNowFullyFunded ? 50 : 0),
          paymentDueDate: newPaymentDueDate, // Update paymentDueDate if it became fully funded
        };
      });
    }
    setCurrentUserAppScore((prevScore) => prevScore + 10);
    alert(
      `You vouched $${vouchedAmount} for ${borrowerName}! Your app score is now ${
        currentUserAppScore + 10
      }. Message: "${message}"`
    );
    setCurrentScreen("LOAN_STATUS");
  };

  const handlePayment = () => {
    alert(
      `Payment of $${userLoanDetails.amount} processed! Your score might increase further. (Demo)`
    );
    setUserLoanDetails((prev) => ({
      ...prev,
      score: prev.score + 20,
      fundedAmount: 0,
      vouchers: [],
    }));
    setCurrentScreen("LOAN_APPLICATION");
  };

  const handleNotReadyToPay = () => {
    alert("Payment extension requested or contact support. (Demo)");
  };

  // --- DEMO BUTTONS TO SIMULATE STATES ---
  const simulatePartiallyFunded = () => {
    const dueDate = new Date();
    dueDate.setDate(dueDate.getDate() + 2);
    setUserLoanDetails({
      borrowerName: "You",
      amount: 100,
      purpose: "new laptop",
      fundedAmount: 50,
      vouchers: [
        {
          name: "Sarah P.",
          amount: 50,
          message: "Hope this helps!",
          avatarUrl: "/placeholder.svg?height=24&width=24",
        },
      ],
      score: 50,
      repaymentDays: 3,
      paymentDueDate: dueDate,
    });
    setCurrentUserAppScore(15);
    setCurrentScreen("LOAN_STATUS");
  };

  const simulateFullyFundedDueToday = () => {
    const today = new Date();
    setUserLoanDetails({
      borrowerName: "You",
      amount: 100,
      purpose: "work equipment",
      fundedAmount: 100,
      vouchers: [
        {
          name: "Alice B.",
          amount: 30,
          message: "Good luck!",
          avatarUrl: "/placeholder.svg?height=24&width=24",
        },
        {
          name: "Bob C.",
          amount: 50,
          message: "You got this!",
          avatarUrl: "/placeholder.svg?height=24&width=24",
        },
        {
          name: "Charlie D.",
          amount: 20,
          avatarUrl: "/placeholder.svg?height=24&width=24",
        },
      ],
      score: 100,
      repaymentDays: 3,
      paymentDueDate: today,
    });
    setCurrentUserAppScore(25);
    setCurrentScreen("LOAN_STATUS");
  };
  // --- END DEMO BUTTONS ---

  if (currentScreen === "LOAN_APPLICATION") {
    return (
      <div className="p-4">
        <LoanApplication onLoanSubmitted={handleLoanSubmitted} />
        <div className="mt-8 space-y-2">
          <button
            onClick={simulatePartiallyFunded}
            className="block w-full p-2 bg-yellow-200 rounded"
          >
            Demo: Partially Funded Loan
          </button>
          <button
            onClick={simulateFullyFundedDueToday}
            className="block w-full p-2 bg-green-200 rounded"
          >
            Demo: Fully Funded Loan (Due Today)
          </button>
        </div>
      </div>
    );
  }

  switch (currentScreen) {
    case "LOAN_STATUS":
      return (
        <LoanStatusScreen
          loanAmount={userLoanDetails.amount}
          loanPurpose={userLoanDetails.purpose}
          fundedAmount={userLoanDetails.fundedAmount}
          vouchers={userLoanDetails.vouchers}
          score={userLoanDetails.score}
          repaymentDays={userLoanDetails.repaymentDays}
          paymentDueDate={userLoanDetails.paymentDueDate}
          onAskForNewLoan={handleAskForNewLoan}
          onShare={handleShareUserLoanToVouchingView}
          onPayNow={handlePayment}
          onNotReadyToPay={handleNotReadyToPay}
        />
      );
    case "COMMUNITY_VOUCHING":
      return (
        <CommunityVouchingScreen
          currentUserScore={currentUserAppScore}
          borrowerName={userLoanDetails.borrowerName}
          loanAmount={userLoanDetails.amount}
          loanPurpose={userLoanDetails.purpose}
          existingVouchersCount={userLoanDetails.vouchers.length}
          repaymentDays={userLoanDetails.repaymentDays}
          onVouch={handleVouchAction}
          onAskForLoan={handleAskForNewLoan}
        />
      );
    default:
      return <LoanApplication onLoanSubmitted={handleLoanSubmitted} />;
  }
}
