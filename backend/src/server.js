require("dotenv").config();

const app = require("./app");
require("./jobs/billCron");

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
