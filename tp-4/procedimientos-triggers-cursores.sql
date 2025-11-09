-- Ejercicio 3
DELIMITER $$

CREATE PROCEDURE VerCuentas()
BEGIN
  SELECT * FROM cuentas;
END$$

DELIMITER ; 

CALL VerCuentas() 

-- Ejercicio4
DELIMITER $$

CREATE PROCEDURE CuentasConSaldoMayorQue(IN limite DECIMAL(10,2))
BEGIN
  SELECT * FROM cuentas
  WHERE saldo > limite;
END$$

DELIMITER ; 

CALL CuentasConSaldoMayorQue(1000.00)

-- Ejercicio 5
DELIMITER $$

CREATE PROCEDURE TotalMovimientosDelMes(
    IN cuenta INT, 
    OUT total DECIMAL(10,2)
)
BEGIN
  SELECT 
    IFNULL(SUM(
        CASE
          WHEN tipo = 'CREDITO' THEN importe
          WHEN tipo = 'DEBITO' THEN -importe
          ELSE 0
        END
      ), 0)
  INTO total
  FROM movimientos
  WHERE numero_cuenta = cuenta 
    AND MONTH(fecha) = MONTH(CURDATE())
    AND YEAR(fecha) = YEAR(CURDATE());
END$$

DELIMITER ; 

CALL TotalMovimientosDelMes(1002, @resultado);
SELECT @resultado; 

-- Ejercicio 6
DELIMITER $$

CREATE PROCEDURE Depositar(
    IN cuenta INT, 
    IN monto DECIMAL(10,2)
)
BEGIN
  UPDATE cuentas
  SET saldo = saldo + monto
  WHERE cuenta = numero_cuenta;
END$$

DELIMITER ; 

CALL  Depositar(1001, 1000.00);
SELECT * FROM cuentas WHERE numero_cuenta = 1001;

-- Ejercicio 7
DELIMITER $$

CREATE PROCEDURE Extraer(
    IN cuenta INT, 
    IN monto DECIMAL(10, 2), 
    OUT mensaje VARCHAR(100)
)
BEGIN
    DECLARE saldo_cuenta DECIMAL(10, 2);

    SELECT saldo INTO saldo_cuenta
    FROM cuentas 
    WHERE numero_cuenta = cuenta; 

    IF saldo_cuenta >= monto THEN
        UPDATE cuentas
        SET saldo = saldo - monto
        WHERE numero_cuenta = cuenta; 
        
        SET mensaje = 'Extraccion exitosa.'; 
    ELSE
        SET mensaje = 'Fondos insuficientes o monto invalido.';
    END IF;
END$$

DELIMITER;

CALL  Extraer(1001, 1000.00, @mensaje_salida);
SELECT @mensaje_salida;
SELECT * FROM cuentas WHERE numero_cuenta = 1001;

-- Ejercicio 8
DELIMITER $$

CREATE TRIGGER ActualizarSaldo
AFTER INSERT ON movimientos
FOR EACH ROW
BEGIN
    IF NEW.tipo = 'CREDITO' THEN
        UPDATE cuentas
        SET saldo = saldo + NEW.importe
        WHERE numero_cuenta = NEW.numero_cuenta;
    ELSEIF NEW.tipo = 'DEBITO' THEN
        UPDATE cuentas
        SET saldo = saldo - NEW.importe
        WHERE numero_cuenta = NEW.numero_cuenta;
    END IF;
END$$

DELIMITER ;

SELECT * FROM cuentas WHERE numero_cuenta = 1003;

INSERT INTO movimientos (numero_cuenta, fecha, tipo, importe) 
VALUES (1003, '2025-11-06', 'CREDITO', 200.00);

SELECT * FROM cuentas WHERE numero_cuenta = 1003;

INSERT INTO movimientos (numero_cuenta, fecha, tipo, importe) 
VALUES (1003, '2025-11-06', 'DEBITO', 150.00);

SELECT * FROM cuentas WHERE numero_cuenta = 1003;

-- Ejercicio 9
DROP TRIGGER IF EXISTS ActualizarSaldo;

DELIMITER $$

CREATE TRIGGER ActualizarSaldo
AFTER INSERT ON movimientos
FOR EACH ROW
BEGIN
  DECLARE saldo_anterior_trg DECIMAL(10,2);
  DECLARE saldo_actual_trg DECIMAL(10,2);
    SELECT saldo INTO saldo_anterior_trg
    FROM cuentas
    WHERE numero_cuenta = NEW.numero_cuenta;
  
    UPDATE cuentas
    SET saldo = saldo + (CASE
                            WHEN NEW.tipo = 'CREDITO' THEN NEW.importe
                            WHEN NEW.tipo = 'DEBITO' THEN -NEW.importe
                            ELSE 0
                        END)
    WHERE numero_cuenta = NEW.numero_cuenta;
    
    SELECT saldo INTO saldo_actual_trg
    FROM cuentas
    WHERE numero_cuenta = NEW.numero_cuenta;
    
    INSERT INTO historial_movimientos (numero_cuenta, numero_movimiento, saldo_anterior, saldo_actual)
    VALUES (NEW.numero_cuenta, NEW.numero_movimiento, saldo_anterior_trg, saldo_actual_trg);
END$$

DELIMITER ;

-- Ejercicio 10
DELIMITER $$

CREATE PROCEDURE TotalMovimientosDelMesCursor(
    IN cuenta INT, 
    OUT total DECIMAL(10,2)
)
BEGIN
    DECLARE v_total DECIMAL(10, 2) DEFAULT 0.00;
    DECLARE v_tipo ENUM('CREDITO', 'DEBITO');
    DECLARE v_importe DECIMAL(10, 2);
    
    DECLARE v_done INT DEFAULT FALSE;

    DECLARE cur_movimientos CURSOR FOR
        SELECT tipo, importe
        FROM movimientos
        WHERE numero_cuenta = cuenta
          AND MONTH(fecha) = MONTH(CURDATE())
          AND YEAR(fecha) = YEAR(CURDATE());

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN cur_movimientos;
    read_loop: LOOP
        FETCH cur_movimientos INTO v_tipo, v_importe;

        IF v_done THEN
            LEAVE read_loop;
        END IF;

        IF v_tipo = 'CREDITO' THEN
            SET v_total = v_total + v_importe;
        ELSEIF v_tipo = 'DEBITO' THEN
            SET v_total = v_total - v_importe;
        END IF;

    END LOOP read_loop;
    CLOSE cur_movimientos;

    SET total = v_total;
END$$

DELIMITER ;

CALL TotalMovimientosDelMesCursor(1002, @resultado_cursor);
SELECT @resultado_cursor;

-- Ejercicio 11
DELIMITER $$

CREATE PROCEDURE AplicarInteresCursor(
    IN p_porcentaje DECIMAL(5, 2), 
    IN p_saldo_minimo DECIMAL(10, 2)
)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_numero_cuenta INT;
    DECLARE v_saldo_actual DECIMAL(10, 2);
    DECLARE v_interes_calculado DECIMAL(10, 2);

    DECLARE cur_cuentas_con_beneficio CURSOR FOR
        SELECT numero_cuenta, saldo
        FROM cuentas
        WHERE saldo > p_saldo_minimo;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN cur_cuentas_con_beneficio;
    aplicar_interes_loop: LOOP
        FETCH cur_cuentas_con_beneficio INTO v_numero_cuenta, v_saldo_actual;

        IF v_done THEN
            LEAVE aplicar_interes_loop;
        END IF;

        SET v_interes_calculado = (v_saldo_actual * p_porcentaje / 100);
        
        UPDATE cuentas
        SET saldo = saldo + v_interes_calculado
        WHERE numero_cuenta = v_numero_cuenta;
        
    END LOOP aplicar_interes_loop;
    CLOSE cur_cuentas_con_beneficio;
END$$

DELIMITER ;

SELECT 'ANTES' AS 'Estado', numero_cuenta, saldo 
FROM cuentas 
WHERE saldo > 3000;

CALL AplicarInteresCursor(10.00, 3000.00);

SELECT 'DESPUES' AS 'Estado', numero_cuenta, saldo 
FROM cuentas 
WHERE numero_cuenta IN (1002, 1004, 1005, 1008);