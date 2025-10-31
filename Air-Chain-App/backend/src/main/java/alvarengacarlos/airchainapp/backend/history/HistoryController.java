package alvarengacarlos.airchainapp.backend.history;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.hibernate.validator.constraints.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping(path = "/histories", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
class HistoryController {
    private final DataSource dataSource;

    public HistoryController(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public void create(@Validated @RequestBody CreateHistoryDto dto) throws SQLException {
        String insert = "INSERT INTO histories (fingerprint, type, description) VALUES (?, ?, ?)";
        try (Connection connection = dataSource.getConnection(); PreparedStatement preparedStatement = connection.prepareStatement(insert)) {
            preparedStatement.setString(1, dto.fingerprint);
            preparedStatement.setString(2, dto.type);
            preparedStatement.setString(3, dto.description);
            preparedStatement.executeUpdate();
        }
    }

    private History.Type mapStringToMapType(String value) {
        return switch (value) {
            case "FIX" -> History.Type.FIX;
            case "MAINTENANCE" -> History.Type.MAINTENANCE;
            default -> throw new RuntimeException(String.format("Type %s is not supported", value));
        };
    }

    @GetMapping
    @ResponseStatus(HttpStatus.OK)
    public List<History> getAll(
            @Min(1)
            @RequestParam(defaultValue = "1")
            Integer page,
            @Min(1)
            @Max(50)
            @RequestParam(defaultValue = "50")
            Integer pageSize
    ) throws SQLException {
        String select = "SELECT * FROM histories LIMIT ?, ?";
        try (Connection connection = dataSource.getConnection(); PreparedStatement preparedStatement = connection.prepareStatement(select)) {
            preparedStatement.setInt(1, (page - 1) * pageSize);
            preparedStatement.setInt(2, pageSize);
            ResultSet resultSet = preparedStatement.executeQuery();
            ArrayList<History> histories = new ArrayList<>();
            while(resultSet.next()) {
                histories.add(makeHistory(resultSet));
            }
            return histories;
        }
    }

    private History makeHistory(ResultSet resultSet) throws SQLException {
        return new History(
                java.util.UUID.fromString(resultSet.getString("id")),
                java.util.UUID.fromString(resultSet.getString("fingerprint")),
                mapStringToMapType(resultSet.getString("type")),
                resultSet.getString("description"),
                resultSet.getTimestamp("createdAt")
        );
    }

    @GetMapping("/{historyId}")
    @ResponseStatus(HttpStatus.OK)
    public History getById(@UUID @PathVariable String historyId) throws HistoryDoesNotExistException, SQLException {
        String select = "SELECT * FROM histories WHERE id = ?";
        try (Connection connection = dataSource.getConnection(); PreparedStatement preparedStatement = connection.prepareStatement(select, ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY)) {
            preparedStatement.setString(1, historyId);
            ResultSet resultSet = preparedStatement.executeQuery();
            Boolean historyExists = resultSet.first();
            if (!historyExists) {
                throw new HistoryDoesNotExistException();
            }
            return makeHistory(resultSet);
        }
    }

    @GetMapping("/fingerprint/{fingerprint}")
    @ResponseStatus(HttpStatus.OK)
    public History getByFingerprint(@UUID @PathVariable String fingerprint) throws HistoryDoesNotExistException, SQLException {
        String select = "SELECT * FROM histories WHERE fingerprint = ?";
        try (Connection connection = dataSource.getConnection(); PreparedStatement preparedStatement = connection.prepareStatement(select, ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY)) {
            preparedStatement.setString(1, fingerprint);
            ResultSet resultSet = preparedStatement.executeQuery();
            Boolean historyExists = resultSet.first();
            if (!historyExists) {
                throw new HistoryDoesNotExistException();
            }
            return makeHistory(resultSet);
        }
    }
}
