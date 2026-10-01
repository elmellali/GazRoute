from fastapi import HTTPException, status


class AppError(HTTPException):
    def __init__(self, status_code: int, detail: str, code: str | None = None):
        super().__init__(status_code=status_code, detail=detail)
        self.code = code or detail


class NotFound(AppError):
    def __init__(self, detail: str = "Not found"):
        super().__init__(status.HTTP_404_NOT_FOUND, detail)


class Forbidden(AppError):
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(status.HTTP_403_FORBIDDEN, detail)


class Unauthorized(AppError):
    def __init__(self, detail: str = "Not authenticated"):
        super().__init__(status.HTTP_401_UNAUTHORIZED, detail)


class Conflict(AppError):
    def __init__(self, detail: str = "Conflict"):
        super().__init__(status.HTTP_409_CONFLICT, detail)


class ValidationException(AppError):
    def __init__(self, detail: str):
        super().__init__(status.HTTP_422_UNPROCESSABLE_CONTENT, detail)


class CreditLocked(AppError):
    def __init__(self, detail: str = "Credit hard lock: unpaid invoices exceed aging threshold"):
        super().__init__(status.HTTP_403_FORBIDDEN, detail, code="CREDIT_HARD_LOCK")


class InsufficientStock(AppError):
    def __init__(self, detail: str = "Insufficient vehicle stock"):
        super().__init__(status.HTTP_409_CONFLICT, detail, code="INSUFFICIENT_STOCK")


class IdempotencyConflict(AppError):
    def __init__(self, detail: str = "Idempotency-Key reused with different payload"):
        super().__init__(status.HTTP_409_CONFLICT, detail, code="IDEMPOTENCY_CONFLICT")
