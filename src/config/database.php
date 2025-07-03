# =====================================
# FICHIER DE CONFIGURATION PHP
# =====================================

# src/config/database.php
<?php
class Database {
    private $host;
    private $db_name;
    private $username;
    private $password;
    private $connection;
    
    public function __construct() {
        $this->host = $_ENV['DB_HOST'] ?? 'localhost';
        $this->db_name = $_ENV['DB_NAME'] ?? 'reservation_db';
        $this->username = $_ENV['DB_USER'] ?? 'reservation_user';
        $this->password = $_ENV['DB_PASSWORD'] ?? 'secure_password';
    }
    
    public function connect() {
        $this->connection = null;
        
        try {
            $dsn = "pgsql:host=" . $this->host . ";dbname=" . $this->db_name;
            $this->connection = new PDO($dsn, $this->username, $this->password);
            $this->connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->connection->exec("set names utf8");
        } catch(PDOException $e) {
            echo "Erreur de connexion: " . $e->getMessage();
        }
        
        return $this->connection;
    }
}
?>