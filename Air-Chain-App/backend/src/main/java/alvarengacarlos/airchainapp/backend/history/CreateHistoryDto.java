package alvarengacarlos.airchainapp.backend.history;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.hibernate.validator.constraints.UUID;

class CreateHistoryDto {
    @UUID(version = 4)
    public String fingerprint;

    @NotNull
    @NotBlank
    @Pattern(regexp = "^(FIX|MAINTENANCE)$", message = "must be 'FIX' or 'MAINTENANCE'")
    public String type;

    @NotNull
    @NotBlank
    @Size(max = 3000)
    public String description;
}
