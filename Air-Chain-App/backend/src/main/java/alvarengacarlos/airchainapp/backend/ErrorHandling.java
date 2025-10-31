package alvarengacarlos.airchainapp.backend;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;

import java.util.Arrays;

@RestControllerAdvice
public class ErrorHandling {
    @ExceptionHandler(exception = MethodArgumentNotValidException.class, produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public String validation(MethodArgumentNotValidException exception) {
        return Arrays.stream(exception.getDetailMessageArguments())
                .reduce("", (acc, elem) -> elem.toString())
                .toString();
    }

    @ExceptionHandler(exception = HandlerMethodValidationException.class, produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public String validation(HandlerMethodValidationException exception) {
        return Arrays.stream(exception.getDetailMessageArguments())
                .reduce("", (acc, elem) -> elem.toString())
                .toString();
    }
}
