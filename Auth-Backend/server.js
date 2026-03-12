const express = require("express");

const app = express();
app.use(express.json());

const PORT = 8081;

// Dummy user database
const users = {
  "bus_101": true,
  "bus_102": true,
  "admin": true
};

app.get("/", (req, res) => {
  res.send("Welcome to the Dummy EMQX Auth Server!");
});

app.post("/mqtt/auth", (req, res) => {

  console.log("Auth Request Received:");
  console.log(req.body);

  const { username, clientid, password } = req.body;

  // Simple validation
  if (!username) {
    return res.json({ result: "deny" });
  }

  // Check if user exists
  if (users[username]) {
    console.log("User allowed:", username);

    return res.json({
      result: "allow",
      is_superuser: false
    });
  }

  console.log("User denied:", username);

  return res.json({
    result: "deny"
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Dummy EMQX auth server running at http://127.0.0.1:${PORT}`);
});
