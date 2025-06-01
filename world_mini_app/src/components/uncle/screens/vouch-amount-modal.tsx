"use client"

import { useState, useEffect, useRef } from "react"

type VouchAmountOption = 10 | 25 | 50 | 75 | 100
const ALL_VOUCH_AMOUNTS: VouchAmountOption[] = [10, 25, 50, 75, 100]

interface VouchAmountModalProps {
  isOpen: boolean
  onClose: () => void
  borrowerName: string
  loanAmount: number // Total loan amount requested by borrower
  loanPurpose: string
  onVouchSubmit: (vouchAmount: VouchAmountOption, message: string) => void
}

export default function VouchAmountModal({
  isOpen,
  onClose,
  borrowerName,
  loanAmount,
  loanPurpose,
  onVouchSubmit,
}: VouchAmountModalProps) {
  const [selectedVouchAmount, setSelectedVouchAmount] = useState<VouchAmountOption | null>(null)
  const [personalMessage, setPersonalMessage] = useState("")
  const [isSubmitting, setIsSubmitting] = useState(false)
  const modalRef = useRef<HTMLDivElement>(null)

  // Filter available vouch amounts based on the total loan amount
  const availableVouchAmounts = ALL_VOUCH_AMOUNTS.filter((amount) => amount <= loanAmount)
  if (availableVouchAmounts.length === 0 && loanAmount > 0) {
    // If all standard options are too high, offer to vouch for the exact loan amount if it's small
    // Or, this case might indicate an issue or require a custom amount input.
    // For now, if loanAmount is less than the smallest option, no standard options are shown.
    // Consider adding loanAmount itself as an option if it's not in ALL_VOUCH_AMOUNTS.
  }

  const initialFocusSetRef = useRef(false)

  // Effect for setting initial focus on modal open
  useEffect(() => {
    if (isOpen) {
      if (!initialFocusSetRef.current) {
        // Set focus to the modal itself only when it initially opens
        // Using a timeout to ensure the element is focusable after render
        const timerId = setTimeout(() => {
          modalRef.current?.focus()
        }, 0)
        initialFocusSetRef.current = true // Mark that initial focus has been set

        return () => clearTimeout(timerId) // Cleanup timer if component unmounts or isOpen changes before timeout
      }
    } else {
      initialFocusSetRef.current = false // Reset when modal closes, so it focuses again next time
    }
  }, [isOpen]) // Only re-run if isOpen changes

  // Effect for managing Escape key to close modal
  useEffect(() => {
    if (!isOpen) return

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose()
      }
    }

    document.addEventListener("keydown", handleEscape)
    return () => {
      document.removeEventListener("keydown", handleEscape)
    }
  }, [isOpen, onClose]) // Re-run if isOpen or onClose changes

  // Effect for resetting selected vouch amount if it becomes invalid
  useEffect(() => {
    if (isOpen) {
      // If a vouch amount is selected but it's no longer in the list of available amounts
      // (e.g., if loanAmount changed dynamically, though less common for a modal prop),
      // then reset the selection.
      if (selectedVouchAmount && !availableVouchAmounts.includes(selectedVouchAmount)) {
        setSelectedVouchAmount(null)
      }
    }
  }, [isOpen, selectedVouchAmount, availableVouchAmounts]) // Re-run if these change

  const handleAmountSelect = (amount: VouchAmountOption) => {
    setSelectedVouchAmount(amount)
  }

  const handleSubmit = async () => {
    if (!selectedVouchAmount) {
      alert("Please select a vouching amount.")
      return
    }
    setIsSubmitting(true)
    await new Promise((resolve) => setTimeout(resolve, 1500))
    onVouchSubmit(selectedVouchAmount, personalMessage)
    setIsSubmitting(false)
    onClose()
  }

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4 z-50"
      role="dialog"
      aria-modal="true"
      aria-labelledby="vouchModalTitle"
      onClick={onClose}
    >
      <div
        ref={modalRef}
        tabIndex={-1}
        className="bg-white p-6 rounded-lg shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header Section */}
        <div className="flex justify-start items-center mb-6 relative">
          <button
            onClick={onClose}
            aria-label="Cancel and close modal"
            className="text-sm text-black font-medium absolute left-0 top-1"
          >
            Cancel
          </button>
          <div className="text-center flex-grow">
            <h2 id="vouchModalTitle" className="text-xl font-bold">
              Vouch for {borrowerName}
            </h2>
            <p className="text-sm text-gray-500">
              ${loanAmount.toFixed(2)} for {loanPurpose}
            </p>
          </div>
        </div>

        {/* Amount Selection */}
        <fieldset className="mb-8">
          <legend className="text-md font-semibold mb-3 text-gray-800 text-left">How much do want to vouch?</legend>
          <div className="flex flex-wrap gap-3 justify-start">
            {availableVouchAmounts.length > 0 ? (
              availableVouchAmounts.map((amount) => (
                <button
                  key={amount}
                  type="button"
                  role="radio"
                  aria-checked={selectedVouchAmount === amount}
                  onClick={() => handleAmountSelect(amount)}
                  className={`py-2 px-4 border rounded-md text-center transition-colors min-w-[60px]
                  ${
                    selectedVouchAmount === amount
                      ? "bg-black text-white border-black"
                      : "bg-white text-black border-gray-300 hover:border-gray-500"
                  }`}
                >
                  <span className="font-semibold">${amount}</span>
                </button>
              ))
            ) : (
              <p className="text-sm text-gray-500">No suitable vouch amounts for this loan.</p>
            )}
          </div>
        </fieldset>

        {/* Personal Message Section */}
        <div className="mb-8">
          <label htmlFor="personalMessage" className="block text-md font-semibold mb-2 text-gray-800 text-left">
            Why are you vouching?
          </label>
          <textarea
            id="personalMessage"
            value={personalMessage}
            onChange={(e) => setPersonalMessage(e.target.value)}
            placeholder="You deserve it"
            maxLength={200}
            rows={3}
            className="w-full p-3 border border-gray-300 rounded-md focus:ring-1 focus:ring-black focus:border-transparent"
          />
          {/* Optional: Character counter can be added here if desired */}
        </div>

        {/* Action Button */}
        <div className="mt-auto">
          <button
            onClick={handleSubmit}
            disabled={!selectedVouchAmount || isSubmitting}
            className="w-full bg-black text-white font-semibold py-3.5 px-4 rounded-md hover:bg-gray-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? "Sending..." : "Send"}
          </button>
        </div>
      </div>
    </div>
  )
}
