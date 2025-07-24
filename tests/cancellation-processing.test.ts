import { describe, it, expect, beforeEach } from "vitest"

describe("Cancellation Processing Contract", () => {
  let contractState = {
    appointmentStatus: new Map(),
    cancellations: new Map(),
    rescheduleRequests: new Map(),
    nextCancellationId: 1,
    cancellationDeadlineHours: 24,
  }
  
  beforeEach(() => {
    contractState = {
      appointmentStatus: new Map(),
      cancellations: new Map(),
      rescheduleRequests: new Map(),
      nextCancellationId: 1,
      cancellationDeadlineHours: 24,
    }
  })
  
  const registerAppointment = (appointmentId, patientId, appointmentDate) => {
    if (appointmentId <= 0 || patientId <= 0 || appointmentDate <= Date.now()) {
      return { error: "ERR-INVALID-INPUT" }
    }
    
    contractState.appointmentStatus.set(appointmentId, {
      status: "scheduled",
      patientId,
      appointmentDate,
      cancellationReason: null,
      cancelledAt: null,
      refundAmount: 0,
    })
    
    return { success: appointmentId }
  }
  
  const cancelAppointment = (appointmentId, reason, refundAmount) => {
    const appointment = contractState.appointmentStatus.get(appointmentId)
    if (!appointment) {
      return { error: "ERR-APPOINTMENT-NOT-FOUND" }
    }
    
    if (appointment.status !== "scheduled") {
      return { error: "ERR-ALREADY-CANCELLED" }
    }
    
    const hoursUntilAppointment = (appointment.appointmentDate - Date.now()) / (1000 * 60 * 60)
    if (hoursUntilAppointment < contractState.cancellationDeadlineHours) {
      return { error: "ERR-TOO-LATE-TO-CANCEL" }
    }
    
    const cancellationId = contractState.nextCancellationId++
    
    appointment.status = "cancelled"
    appointment.cancellationReason = reason
    appointment.cancelledAt = Date.now()
    appointment.refundAmount = refundAmount
    
    contractState.cancellations.set(cancellationId, {
      appointmentId,
      patientId: appointment.patientId,
      cancellationType: "patient-initiated",
      reason,
      refundProcessed: false,
      cancelledAt: Date.now(),
    })
    
    return { success: cancellationId }
  }
  
  const requestReschedule = (appointmentId, newDate) => {
    const appointment = contractState.appointmentStatus.get(appointmentId)
    if (!appointment) {
      return { error: "ERR-APPOINTMENT-NOT-FOUND" }
    }
    
    if (appointment.status !== "scheduled") {
      return { error: "ERR-ALREADY-CANCELLED" }
    }
    
    if (newDate <= Date.now()) {
      return { error: "ERR-INVALID-INPUT" }
    }
    
    contractState.rescheduleRequests.set(appointmentId, {
      originalDate: appointment.appointmentDate,
      requestedDate: newDate,
      approved: false,
      processedAt: Date.now(),
    })
    
    return { success: true }
  }
  
  const isCancelled = (appointmentId) => {
    const appointment = contractState.appointmentStatus.get(appointmentId)
    return appointment ? appointment.status === "cancelled" : false
  }
  
  it("should register appointment successfully", () => {
    const futureDate = Date.now() + 86400000 // 24 hours from now
    const result = registerAppointment(1, 100, futureDate)
    
    expect(result.success).toBe(1)
    expect(contractState.appointmentStatus.has(1)).toBe(true)
    
    const appointment = contractState.appointmentStatus.get(1)
    expect(appointment.status).toBe("scheduled")
    expect(appointment.patientId).toBe(100)
  })
  
  it("should cancel appointment successfully", () => {
    const futureDate = Date.now() + 48 * 60 * 60 * 1000 // 48 hours from now
    registerAppointment(1, 100, futureDate)
    
    const result = cancelAppointment(1, "Personal emergency", 50)
    
    expect(result.success).toBe(1)
    expect(isCancelled(1)).toBe(true)
    
    const appointment = contractState.appointmentStatus.get(1)
    expect(appointment.status).toBe("cancelled")
    expect(appointment.cancellationReason).toBe("Personal emergency")
    expect(appointment.refundAmount).toBe(50)
  })
  
  it("should prevent cancellation too close to appointment", () => {
    const nearFutureDate = Date.now() + 12 * 60 * 60 * 1000 // 12 hours from now
    registerAppointment(1, 100, nearFutureDate)
    
    const result = cancelAppointment(1, "Last minute change", 0)
    expect(result.error).toBe("ERR-TOO-LATE-TO-CANCEL")
  })
  
  it("should handle reschedule requests", () => {
    const futureDate = Date.now() + 86400000
    const newDate = Date.now() + 2 * 86400000
    
    registerAppointment(1, 100, futureDate)
    
    const result = requestReschedule(1, newDate)
    expect(result.success).toBe(true)
    
    const rescheduleRequest = contractState.rescheduleRequests.get(1)
    expect(rescheduleRequest.originalDate).toBe(futureDate)
    expect(rescheduleRequest.requestedDate).toBe(newDate)
    expect(rescheduleRequest.approved).toBe(false)
  })
  
  it("should prevent duplicate cancellations", () => {
    const futureDate = Date.now() + 48 * 60 * 60 * 1000
    registerAppointment(1, 100, futureDate)
    cancelAppointment(1, "First cancellation", 50)
    
    const result = cancelAppointment(1, "Second attempt", 25)
    expect(result.error).toBe("ERR-ALREADY-CANCELLED")
  })
})
