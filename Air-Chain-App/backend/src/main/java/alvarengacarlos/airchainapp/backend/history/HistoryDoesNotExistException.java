package alvarengacarlos.airchainapp.backend.history;

class HistoryDoesNotExistException extends Exception {
    public HistoryDoesNotExistException() {
        super("History does not exist");
    }
}
