CREATE SCHEMA IF NOT EXISTS jende AUTHORIZATION postgres;

-- Empleados y administradores del café
CREATE TABLE jende.users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name VARCHAR(150),
  email VARCHAR(150) UNIQUE,
  role VARCHAR(30) NOT NULL, -- 'admin' | 'empleado'
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Clientes del café
CREATE TABLE jende.clients (
  id SERIAL PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(50),
  email VARCHAR(150),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Productos del menú
CREATE TABLE jende.products (
  id SERIAL PRIMARY KEY,
  sku VARCHAR(50) UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  category VARCHAR(50) NOT NULL, -- café, postre, combo
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Pedidos
CREATE TABLE jende.orders (
  id SERIAL PRIMARY KEY,
  client_id INTEGER REFERENCES jende.clients(id) ON DELETE SET NULL,
  user_id INTEGER REFERENCES jende.users(id) ON DELETE SET NULL,
  table_number VARCHAR(10), -- mesa 1, mesa 2, o null si es para llevar
  status VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Detalle de pedidos
CREATE TABLE jende.order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES jende.orders(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES jende.products(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  line_total NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Devoluciones
CREATE TABLE jende.returns (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES jende.orders(id) ON DELETE SET NULL,
  order_item_id INTEGER REFERENCES jende.order_items(id) ON DELETE SET NULL,
  client_id INTEGER REFERENCES jende.clients(id) ON DELETE SET NULL,
  reason TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO jende.products (sku, name, description, price, stock, category)
VALUES
('CAF001', 'Espresso', 'Café espresso corto', 4000, 100, 'café'),
('CAF002', 'Capuccino', 'Capuccino con espuma de leche', 6000, 80, 'café'),
('CAF003', 'Latte', 'Café latte con leche vaporizada', 6500, 80, 'café'),
('POS001', 'Brownie de chocolate', 'Brownie artesanal con nueces', 5000, 50, 'postre'),
('POS002', 'Cheesecake', 'Cheesecake de frutos rojos', 7000, 40, 'postre'),
('COM001', 'Combo Jende', 'Capuccino + Brownie', 10000, 30, 'combo');

-- Rol administrador del café
CREATE ROLE jende_admin WITH LOGIN PASSWORD 'CafeAdmin2025!' SUPERUSER;

-- Rol empleados (cajeros, meseros)
CREATE ROLE jende_employee WITH LOGIN PASSWORD 'CafeEmpleado2025!';

-- Permisos empleados: Insert/Update pero no Delete
GRANT USAGE ON SCHEMA jende TO jende_employee;
GRANT SELECT, INSERT, UPDATE ON jende.products TO jende_employee;
GRANT SELECT, INSERT, UPDATE ON jende.orders TO jende_employee;
GRANT SELECT, INSERT, UPDATE ON jende.order_items TO jende_employee;
GRANT SELECT, INSERT, UPDATE ON jende.clients TO jende_employee;

CREATE OR REPLACE PROCEDURE jende.registrar_pedido(
  p_client_id INTEGER,
  p_user_id INTEGER,
  p_table_number VARCHAR,
  p_items JSON
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id INTEGER;
  v_item RECORD;
  v_unit_price NUMERIC(12,2);
  v_line_total NUMERIC(12,2);
  v_total NUMERIC(12,2) := 0;
BEGIN
  INSERT INTO jende.orders(client_id, user_id, table_number, status, total)
  VALUES (p_client_id, p_user_id, p_table_number, 'PENDIENTE', 0)
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM json_to_recordset(p_items)
    AS (product_id INTEGER, quantity INTEGER)
  LOOP
    SELECT price INTO v_unit_price FROM jende.products WHERE id = v_item.product_id;

    v_line_total := v_unit_price * v_item.quantity;

    INSERT INTO jende.order_items(order_id, product_id, quantity, unit_price, line_total)
    VALUES (v_order_id, v_item.product_id, v_item.quantity, v_unit_price, v_line_total);

    v_total := v_total + v_line_total;
  END LOOP;

  UPDATE jende.orders SET total = v_total WHERE id = v_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION jende.ventas_totales()
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
  v_total NUMERIC(14,2);
BEGIN
  SELECT COALESCE(SUM(total),0) INTO v_total
  FROM jende.orders
  WHERE status NOT IN ('CANCELADO');
  RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION jende.fn_actualizar_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE jende.products
  SET stock = stock - NEW.quantity
  WHERE id = NEW.product_id;

  IF (SELECT stock FROM jende.products WHERE id = NEW.product_id) < 0 THEN
    RAISE EXCEPTION 'Stock insuficiente en producto %', NEW.product_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER actualizar_stock
AFTER INSERT ON jende.order_items
FOR EACH ROW
EXECUTE FUNCTION jende.fn_actualizar_stock();


SELECT * FROM jende.clients;
SELECT * FROM jende.order_items;
SELECT * FROM jende.products;

INSERT INTO jende.clients (id, name, email)
VALUES (1, 'Cliente Test', 'cliente@test.com');

INSERT INTO jende.users (id, username, role,  password_hash)
VALUES (1, 'Admin', 'cajero',1);

REVOKE DELETE ON jende.orders FROM "jende_employee";
REVOKE DELETE ON jende.products FROM "jende_employee";
REVOKE DELETE ON jende.order_items FROM "jende_employee";
REVOKE DELETE ON jende.clients FROM "jende_employee";

SELECT * FROM jende.products;

SELECT * FROM jende.order_items;

SET role jende_employee;
SET role jende_admin;

DELETE FROM jende.orders;

RESET ROLE;



