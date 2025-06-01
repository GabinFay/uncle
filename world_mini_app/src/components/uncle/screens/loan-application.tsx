"use client"

import type React from "react"

import { useState } from "react"

type LoanAmount = 10 | 25 | 50 | 75 | 100

interface LoanApplicationProps {
  onLoanSubmitted?: (amount: LoanAmount, purpose: string) => void
}

export default function LoanApplication({ onLoanSubmitted }: LoanApplicationProps) {
  const [selectedAmount, setSelectedAmount] = useState<LoanAmount | null>(null)
  const [purpose, setPurpose] = useState<string>("")
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)

  const handleAmountSelect = (amount: LoanAmount) => {
    setSelectedAmount(amount)
    setError(null)
  }

  const handlePurposeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPurpose(e.target.value)
    setError(null)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    // Form validation
    if (!selectedAmount) {
      setError("Please select a loan amount")
      return
    }

    if (!purpose.trim()) {
      setError("Please enter the purpose of your loan")
      return
    }

    // Submit form
    setIsSubmitting(true)

    // Simulate API call
    setTimeout(() => {
      console.log("Form submitted:", { selectedAmount, purpose })
      setIsSubmitting(false)
      if (onLoanSubmitted && selectedAmount) {
        // Ensure selectedAmount is not null
        onLoanSubmitted(selectedAmount, purpose)
      }
      // Reset form or redirect user
    }, 1000)
  }

  const handleCancel = () => {
    // Handle cancel action (e.g., navigate back)
    console.log("Cancelled")
  }

  return (
    <div className="min-h-screen bg-white p-4 max-w-md mx-auto">
      <header className="flex items-center justify-between mb-8">
        <button onClick={handleCancel} className="text-black font-medium" aria-label="Cancel loan application">
          Cancel
        </button>
        <h1 className="text-xl font-bold text-center flex-1">Ask for a loan</h1>
        <div className="w-14"></div> {/* Spacer for centering title */}
      </header>

      <form onSubmit={handleSubmit} className="flex flex-col space-y-8">
        <section className="mt-12">
          <h2 className="text-center mb-4 font-medium">How much do you need?</h2>
          <div className="flex justify-between gap-2">
            {[10, 25, 50, 75, 100].map((amount) => (
              <button
                key={amount}
                type="button"
                onClick={() => handleAmountSelect(amount as LoanAmount)}
                className={`flex-1 py-2 px-1 border rounded-md text-center ${
                  selectedAmount === amount ? "border-black bg-gray-100" : "border-gray-300"
                }`}
                aria-pressed={selectedAmount === amount}
                aria-label={`$${amount}`}
              >
                ${amount}
              </button>
            ))}
          </div>
        </section>

        <section className="mt-8">
          <h2 className="mb-2 font-medium">Why do you need it?</h2>
          <input
            type="text"
            value={purpose}
            onChange={handlePurposeChange}
            placeholder="Work equipment"
            className="w-full p-4 border border-gray-300 rounded-md"
            aria-label="Purpose of loan"
          />
        </section>

        {error && (
          <div className="text-red-500 text-sm" role="alert">
            {error}
          </div>
        )}

        <section className="mt-auto pt-12">
          <button
            type="submit"
            disabled={isSubmitting}
            className="w-full bg-black text-white font-bold py-4 px-4 rounded-md hover:bg-gray-800 transition-colors disabled:opacity-70"
            aria-label="Submit loan application"
          >
            {isSubmitting ? "Submitting..." : "Submit"}
          </button>
        </section>
      </form>
    </div>
  )
}
