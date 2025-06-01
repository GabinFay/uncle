"use client"

import { useState } from "react"
import VouchAmountModal from "./vouch-amount-modal" // Import the modal

interface CommunityVouchingScreenProps {
  currentUserScore: number
  borrowerName: string
  loanAmount: number
  loanPurpose: string
  existingVouchersCount: number
  repaymentDays: number
  onVouch: (borrowerName: string, amount: number, message: string) => void // Updated to include message
  onAskForLoan?: () => void
}

export default function CommunityVouchingScreen({
  currentUserScore,
  borrowerName,
  loanAmount,
  loanPurpose,
  existingVouchersCount,
  repaymentDays,
  onVouch, // This will be called by the modal
  onAskForLoan,
}: CommunityVouchingScreenProps) {
  const [isVouchModalOpen, setIsVouchModalOpen] = useState(false)

  const handleOpenVouchModal = () => {
    setIsVouchModalOpen(true)
  }

  const handleCloseVouchModal = () => {
    setIsVouchModalOpen(false)
  }

  const handleVouchSubmitFromModal = (vouchAmount: number, message: string) => {
    // The onVouch prop of CommunityVouchingScreen is called here
    onVouch(borrowerName, vouchAmount, message)
    // Modal closes itself after submission
  }

  const handleAskForNewLoan = () => {
    if (onAskForLoan) {
      onAskForLoan()
    } else {
      console.log("Ask for a loan clicked from vouching screen")
    }
  }

  return (
    <>
      <div className="min-h-screen bg-white flex flex-col items-center justify-between p-6 max-w-md mx-auto">
        {/* Header Section */}
        <div className="w-full text-center mt-8">
          <p className="text-gray-500 text-sm">Your score</p>
          <div className="mt-2 w-16 h-16 bg-green-500 rounded-full flex items-center justify-center mx-auto">
            <span className="text-white text-2xl font-bold">{currentUserScore}</span>
          </div>
        </div>

        {/* Loan Request Section */}
        <div className="text-center my-10">
          <h1 className="text-2xl sm:text-3xl font-bold text-black">
            {borrowerName} is asking ${loanAmount.toFixed(2)}
          </h1>
          <p className="text-lg sm:text-xl text-black mt-1">for {loanPurpose}</p>
        </div>

        {/* Social Proof Section */}
        {existingVouchersCount > 0 && (
          <div className="flex items-center justify-center space-x-2 my-6">
            <div className="flex -space-x-1">
              {Array.from({ length: Math.min(existingVouchersCount, 2) }).map((_, i) => (
                <div key={i} className="w-5 h-5 bg-gray-300 rounded-full border-2 border-white"></div>
              ))}
            </div>
            <p className="text-sm text-gray-600">
              {existingVouchersCount} other friend{existingVouchersCount > 1 ? "s" : ""} vouched
            </p>
          </div>
        )}
        {existingVouchersCount === 0 && (
          <div className="my-6 h-10 flex items-center justify-center">
            <p className="text-sm text-gray-500 text-center">Be the first to vouch!</p>
          </div>
        )}

        {/* Primary Action Button - Opens Modal */}
        <div className="w-full flex flex-col items-center mt-auto space-y-4">
          <button
            onClick={handleOpenVouchModal} // Changed to open modal
            className="bg-black text-white font-semibold py-3.5 px-8 rounded-lg hover:bg-gray-800 transition-colors w-full max-w-xs h-[50px]"
            aria-label={`Vouch for ${borrowerName}`}
          >
            Vouch for {borrowerName}
          </button>

          {/* Loan Terms Section */}
          <div className="text-center text-sm text-gray-700">
            <p>
              He will have <span className="font-bold">{repaymentDays} days</span>
            </p>
            <p>to pay you back</p>
          </div>

          {/* Secondary Action */}
          <button
            onClick={handleAskForNewLoan}
            className="text-black mt-6 mb-4 text-sm underline"
            aria-label="Ask for a loan"
          >
            Ask for a loan
          </button>
        </div>
      </div>

      {/* Vouch Amount Modal */}
      <VouchAmountModal
        isOpen={isVouchModalOpen}
        onClose={handleCloseVouchModal}
        borrowerName={borrowerName}
        loanAmount={loanAmount}
        loanPurpose={loanPurpose}
        onVouchSubmit={handleVouchSubmitFromModal}
      />
    </>
  )
}
