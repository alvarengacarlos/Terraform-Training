package alvarengacarlos.airchainapp.backend.history;

import java.util.Date;
import java.util.UUID;

class History {
    public UUID id;
    public UUID fingerprint;
    public Type type;
    public String description;
    public Date createdAt;

    public History(UUID id, UUID fingerprint, Type type, String description, Date createdAt) {
        this.id = id;
        this.fingerprint = fingerprint;
        this.type = type;
        this.description = description;
        this.createdAt = createdAt;
    }

    enum Type {
        FIX,
        MAINTENANCE
    }
}
