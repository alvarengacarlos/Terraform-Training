export async function handler(event, context) {
    console.info(`index::handler::The event is ${JSON.stringify(event, null, 2)}`)
    console.info(`index::handler::The context is ${JSON.stringify(context, null, 2)}`)

    console.info(`index::handler::The DB_URL ${process.env.DB_URL}`)
    const body = `
<html>
<header>
    <title>Hello World</title>    
</header>
<body>
    <h1>Hello from Amazon Lambda</h1>    
</body>    
</html>
    `
    return {
        isBase64Encoded: false,
        statusCode: 200,
        body: body,
        headers: {
            "Content-Type": "text/html"
        }
    }
}
