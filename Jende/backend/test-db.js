import dotenv from "dotenv";
import pkg from "pg";

dotenv.config();
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

(async () => {
  try {
    const result = await pool.query("SELECT current_database(), current_user");
    console.log("✅ Conectado a:", result.rows[0]);
  } catch (err) {
    console.error("❌ Error de conexión:", err.message);
  } finally {
    await pool.end();
  }
})();
