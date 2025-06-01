"use client"
import { useState } from "react"

interface Voucher {
  name: string
  amount: number
  avatarUrl?: string
  message?: string
}

interface PaymentDueInfo {
  text: string
  isDueToday: boolean
}

interface LoanStatusScreenProps {
  loanAmount: number
  loanPurpose: string
  fundedAmount: number
  vouchers: Voucher[]
  score?: number
  repaymentDays?: number
  paymentDueDate?: Date
  onAskForNewLoan?: () => void
  onShare?: () => void
  onPayNow?: () => void
  onNotReadyToPay?: () => void
}

export default function LoanStatusScreen({
  loanAmount,
  loanPurpose,
  fundedAmount,
  vouchers = [],
  score = 0,
  repaymentDays = 3,
  paymentDueDate,
  onAskForNewLoan,
  onShare,
  onPayNow,
  onNotReadyToPay,
}: LoanStatusScreenProps) {
  const [isSharing, setIsSharing] = useState(false)
  const [isPaying, setIsPaying] = useState(false)

  const isFullyFunded = fundedAmount >= loanAmount
  const remainingAmount = Math.max(0, loanAmount - fundedAmount)

  const getPaymentDueInfo = (): PaymentDueInfo => {
    if (!paymentDueDate) {
      return { text: `Pay your friends in ${repaymentDays} days`, isDueToday: false }
    }
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const dueDate = new Date(paymentDueDate) // Ensure it's a new Date object
    dueDate.setHours(0, 0, 0, 0)

    const diffTime = dueDate.getTime() - today.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    if (diffDays === 0) {
      return { text: "Your payment is due today.", isDueToday: true }
    } else if (diffDays === 1) {
      return { text: "Your payment is due tomorrow.", isDueToday: false }
    } else if (diffDays > 1) {
      return { text: `Your payment is due in ${diffDays} days.`, isDueToday: false }
    } else {
      return {
        text: `Your payment was due ${Math.abs(diffDays)} day${Math.abs(diffDays) > 1 ? "s" : ""} ago.`,
        isDueToday: false,
      }
    }
  }

  const paymentDueInfo = getPaymentDueInfo()

  const handleShare = async () => {
    if (onShare) {
      onShare()
    } else {
      setIsSharing(true)
      // Fallback navigator.share logic
      setIsSharing(false)
    }
  }

  const handlePayNow = async () => {
    if (onPayNow) {
      setIsPaying(true)
      await new Promise((resolve) => setTimeout(resolve, 1500))
      onPayNow()
      setIsPaying(false)
      alert("Payment successful! (Demo)")
    } else {
      alert("Pay Now clicked! (Implement payment flow)")
    }
  }

  const handleNotReadyToPay = () => {
    if (onNotReadyToPay) {
      onNotReadyToPay()
    } else {
      alert("Not ready to pay yet? Contact support or check options. (Demo)")
    }
  }

  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-between p-6 max-w-md mx-auto">
      <div className="w-full text-center mt-8">
        <p className="text-gray-500 text-sm">Your score</p>
        <p className="text-6xl font-bold text-green-500 my-2 relative inline-block">
          {score}
          <span className="absolute bottom-[-8px] left-0 right-0 h-1 bg-green-500"></span>
        </p>
        {isFullyFunded && <p className="text-green-500 font-semibold mt-4 text-lg">You are fully funded!</p>}
      </div>

      <div className="text-center my-10">
        <p className="text-3xl font-bold text-black">${loanAmount.toFixed(2)} for</p>
        <p className="text-xl text-black mt-1">{loanPurpose}</p>
      </div>

      <div className="w-full my-6 space-y-3">
        {vouchers.length > 0 ? (
          <div className="text-center">
            <div className="flex items-center justify-center space-x-1 mb-1">
              {Array.from({ length: Math.min(vouchers.length, 3) }).map((_, i) => (
                <div key={`dot-${i}`} className="w-3 h-3 bg-gray-300 rounded-full"></div>
              ))}
            </div>
            <p className="text-sm text-gray-600">
              {vouchers.length} friend{vouchers.length !== 1 ? "s" : ""} vouched for you
            </p>
          </div>
        ) : (
          !isFullyFunded && <p className="text-center text-gray-600">Waiting for vouches...</p>
        )}
      </div>

      <div className="w-full flex flex-col items-center mt-auto">
        {isFullyFunded ? (
          <>
            <button
              onClick={handlePayNow}
              disabled={isPaying}
              className="bg-black text-white font-semibold py-3 px-12 rounded-lg hover:bg-gray-800 transition-colors disabled:opacity-50 w-full max-w-xs h-[50px]"
            >
              {isPaying ? "Processing..." : "Pay now"}
            </button>
            <div className="text-center mt-4">
              <p className="text-sm text-gray-700">{paymentDueInfo.text}</p>
              {paymentDueInfo.isDueToday && (
                <button onClick={handleNotReadyToPay} className="text-sm text-red-500 underline hover:text-red-700">
                  Not ready to pay yet?
                </button>
              )}
              {!paymentDueInfo.isDueToday && <p className="text-sm text-gray-500">to keep your score</p>}
            </div>
          </>
        ) : (
          <>
            <button
              onClick={handleShare}
              disabled={isSharing}
              className="bg-black text-white font-semibold py-3 px-12 rounded-lg hover:bg-gray-800 transition-colors disabled:opacity-50 w-full max-w-xs h-[50px]"
            >
              {isSharing ? "Sharing..." : "Share"}
            </button>
            <p className="text-center text-gray-700 mt-4">
              You just need <span className="font-semibold text-black">${remainingAmount.toFixed(2)}</span> more
            </p>
          </>
        )}

        <button onClick={onAskForNewLoan} className="text-black mt-8 mb-4 text-sm underline">
          Ask for a new loan
        </button>
      </div>
    </div>
  )
}
