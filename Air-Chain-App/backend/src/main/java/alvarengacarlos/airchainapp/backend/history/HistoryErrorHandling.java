package alvarengacarlos.airchainapp.backend.history;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@RestControllerAdvice
class HistoryErrorHandling extends ResponseEntityExceptionHandler {
    @ExceptionHandler(exception = HistoryDoesNotExistException.class, produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public String historyDoesNotExist(Exception exception) {
        return exception.getMessage();
    }
}
