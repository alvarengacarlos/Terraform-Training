const Status = Object.freeze({
    SUCCESS: "SUCCESS",
    FAIL: "FAIL"
})

export async function handler(status) {
    const isValidStatus = Object.values(Status).includes(status)
    if (!isValidStatus) {
        const message = `The status '${status}' is invalid`
        console.error(`index::handler::${message}`)
        throw new Error(message)
    }

    if (status === Status.SUCCESS) {
        const message = "The status is 'SUCCESS'"
        console.info(`index::handler::${message}`)
        return message
    } else {
        const message = "The status is 'FAIL'"
        console.info(`index::handler::${message}`)
        throw new Error(message)
    }
}
