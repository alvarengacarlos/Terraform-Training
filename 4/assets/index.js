document.getElementById("hello-world-btn").addEventListener("click", () => {
    const h1 = document.getElementById("hello-world-h1")
    if (h1.style.color === "coral") {
        h1.style.color = "black"
    } else {
        h1.style.color = "coral"
    }
    console.log("Hello there")
})