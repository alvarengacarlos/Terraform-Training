package alvarengacarlos.airchainapp.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;

//TODO: Implements this integration test
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
public class ApplicationIT {
    private @Autowired DataSource dataSource;

    @Test
    void shouldGetAllHistories() {
    }
}
