SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS MonFire;
USE MonFire;

CREATE TABLE empresa (
    id INT PRIMARY KEY AUTO_INCREMENT,
    razao_social VARCHAR(50) NOT NULL,
    cnpj CHAR(14) NOT NULL UNIQUE,
    dtHr DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    unidade VARCHAR(50) NOT NULL
);


CREATE TABLE usuario (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL,
    email VARCHAR(50) NOT NULL UNIQUE,
    senha_hash VARCHAR(90) NOT NULL,
    ultimo_acesso DATETIME,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    dtHr_desativacao DATETIME,
    fk_empresa INT NOT NULL,
    CONSTRAINT empresa_usuario FOREIGN KEY (fk_empresa) REFERENCES empresa(id),
    CONSTRAINT ck_usuario_desativacao CHECK (
        (ativo = 1 AND dtHr_desativacao IS NULL)
        OR (ativo = 0 AND dtHr_desativacao IS NOT NULL)
    )
);

CREATE TABLE cargo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    funcao VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE usuario_cargo (
    fk_usuario INT NOT NULL,
    fk_cargo INT NOT NULL,
    dtHr_inicio DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    saida DATETIME,
    PRIMARY KEY (fk_usuario, fk_cargo),
    CONSTRAINT fk_usuario_cargo_usuario FOREIGN KEY (fk_usuario) REFERENCES usuario(id),
    CONSTRAINT fk_usuario_cargo_cargo FOREIGN KEY (fk_cargo) REFERENCES cargo(id),
    CONSTRAINT ck_usuario_cargo_periodo CHECK (saida IS NULL OR saida >= dtHr_inicio)
);

CREATE TABLE maquina (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL,
    hostname VARCHAR(255),
    mac CHAR(17),
    ip VARCHAR(45),
    sistema_operacional VARCHAR(100),
    situacao ENUM('PENDENTE', 'ATIVA', 'INATIVA') NOT NULL DEFAULT 'PENDENTE',
    dtHr_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    dtHr_ativacao DATETIME,
    fk_empresa INT NOT NULL,
    CONSTRAINT empresa_maquina FOREIGN KEY (fk_empresa) REFERENCES empresa(id),
    CONSTRAINT uk_empresa_mac UNIQUE (fk_empresa, mac),
    CONSTRAINT ck_maquina_ativa_identificada CHECK (
        situacao <> 'ATIVA'
        OR (
            hostname IS NOT NULL
            AND mac IS NOT NULL
            AND ip IS NOT NULL
            AND sistema_operacional IS NOT NULL
        )
    )
);

-- Guarda somente o hash do código atual de uma máquina pendente.
-- A restrição UNIQUE em fk_maquina permite apenas um código vigente por máquina.
CREATE TABLE codigo_ativacao (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo_hash CHAR(64) NOT NULL UNIQUE,
    dtHr_geracao DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    dtHr_expiracao DATETIME NOT NULL,
    fk_maquina INT NOT NULL UNIQUE,
    CONSTRAINT fk_codigo_ativacao_maquina
        FOREIGN KEY (fk_maquina) REFERENCES maquina(id),
    CONSTRAINT ck_codigo_ativacao_validade
        CHECK (dtHr_expiracao > dtHr_geracao)
);

CREATE TABLE nivel_alerta (
    id INT PRIMARY KEY AUTO_INCREMENT,
    estado VARCHAR(40) NOT NULL UNIQUE,
    descricao VARCHAR(150)
);

CREATE TABLE metrica_componente (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(20) NOT NULL,
    unidade_medida VARCHAR(20) NOT NULL,
    especificacao VARCHAR(100) NOT NULL,
    CONSTRAINT uk_metrica_componente UNIQUE (nome, unidade_medida)
);


CREATE TABLE tipo_componente (
    id INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    nome VARCHAR(30) NOT NULL,
    fk_metrica_componente INT NOT NULL,
    CONSTRAINT fk_tipo_componente_metrica
        FOREIGN KEY (fk_metrica_componente) REFERENCES metrica_componente(id),
    CONSTRAINT uk_tipo_componente_metrica UNIQUE (nome, fk_metrica_componente)
);


CREATE TABLE componente (
    id INT PRIMARY KEY AUTO_INCREMENT,
    status_atividade TINYINT(1) NOT NULL DEFAULT 1,
    fk_tipo_componente INT NOT NULL UNIQUE,
    CONSTRAINT fk_componente_tipo
        FOREIGN KEY (fk_tipo_componente) REFERENCES tipo_componente(id)
);


CREATE TABLE configuracao_maquina (
    id INT PRIMARY KEY AUTO_INCREMENT,
    fk_maquina INT NOT NULL,
    fk_componente INT NOT NULL,
    ativa TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_configuracao_maquina FOREIGN KEY (fk_maquina) REFERENCES maquina(id),
    CONSTRAINT fk_configuracao_componente FOREIGN KEY (fk_componente) REFERENCES componente(id),
    CONSTRAINT uk_configuracao_maquina UNIQUE (fk_maquina, fk_componente)
);


CREATE TABLE metrica_alerta (
    id INT PRIMARY KEY AUTO_INCREMENT,
    fk_configuracao_maquina INT NOT NULL,
    fk_nivel_alerta INT NOT NULL,
    limite DECIMAL(12,4) NOT NULL,
    CONSTRAINT fk_metrica_alerta_configuracao
        FOREIGN KEY (fk_configuracao_maquina) REFERENCES configuracao_maquina(id),
    CONSTRAINT fk_metrica_alerta_nivel
        FOREIGN KEY (fk_nivel_alerta) REFERENCES nivel_alerta(id),
    CONSTRAINT uk_metrica_alerta_nivel
        UNIQUE (fk_configuracao_maquina, fk_nivel_alerta),
    CONSTRAINT ck_metrica_alerta_limite CHECK (limite >= 0)
);


CREATE TABLE captura (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    valor DOUBLE NOT NULL,
    dtHr DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fk_configuracao_maquina INT NOT NULL,
    CONSTRAINT fk_captura_configuracao
        FOREIGN KEY (fk_configuracao_maquina) REFERENCES configuracao_maquina(id)
);

-- Registra futuramente qual limite foi atingido por uma captura.
-- A geração do alerta ainda não foi implementado
CREATE TABLE alerta (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    fk_captura BIGINT NOT NULL,
    fk_metrica_alerta INT NOT NULL,
    dtHr DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_alerta_captura FOREIGN KEY (fk_captura) REFERENCES captura(id),
    CONSTRAINT fk_alerta_metrica FOREIGN KEY (fk_metrica_alerta) REFERENCES metrica_alerta(id),
    CONSTRAINT uk_alerta_captura UNIQUE (fk_captura)
);

INSERT INTO empresa (razao_social, cnpj, unidade) VALUES
    ('Monitoramento de Hardware Bombeiro LTDA', '01234567891234', 'MonFire'),
    ('Sptech Educacao Executiva e Servicos Ltda', '26217610000135', 'São Paulo Tech School');

INSERT INTO cargo (funcao) VALUES
    ('Administrador'),
    ('Gerente'),
    ('Técnico'),
    ('Comum');

-- O último acesso agora é armazenado uma única vez na conta do usuário.
INSERT INTO usuario (
    nome, email, senha_hash, ultimo_acesso, ativo, dtHr_desativacao, fk_empresa
) VALUES
    ('Alexandre Tabacchi', 'alexandre@sptech.school', '$2b$10$KBMteNmthOSspRt3ri5QquIIk8jGYlCvgf.x.plubY5gYO/qdNKpW', '2026-10-09 09:12:00', 1, NULL, 2),
    ('Felipe Amoroso', 'felipe@sptech.school', '$2b$10$KIiaFarAERlI1uJ47EXTneHvwhDCiSgtyyDwpRgb.catVd8dx6CCO', '2026-10-09 08:47:00', 1, NULL, 2),
    ('Gabryel Moura', 'gabryel@sptech.school', '$2b$10$bKXS2JLQehn3LoB4f6D7oeC6kLAt8ef94DLQlLBjGBQJNIOfikq6q', '2026-10-09 07:30:00', 1, NULL, 2),
    ('Helena Caporicci', 'helena@sptech.school', '$2b$10$h5jpQUCYkC9db5QinRgNtuua4HOgdzpwNOvOA9Rvbi9yXtGB4SLfG', '2026-10-08 22:05:00', 1, NULL, 2),
    ('Maria Luiza Vieira', 'marialuiza@sptech.school', '$2b$10$wljkR8Wskq.0MpLfFocobu0NYhOyV166.Vy.4pPcA1ntxtIFIRZtm', '2026-09-25 14:20:00', 0, '2026-09-25 14:20:00', 2),
    ('Pedro Caparroz', 'pedro@sptech.school', '$2b$10$TseNY21dVYkXYSztsOgJB.z0zs8TFvZ1EXPHvEZeNzqJTFSNclnQC', '2026-09-18 10:02:00', 0, '2026-09-18 10:02:00', 2);

INSERT INTO usuario_cargo (fk_usuario, fk_cargo, dtHr_inicio, saida) VALUES
    (1, 1, '2026-01-01 00:00:00', NULL),
    (2, 1, '2026-01-01 00:00:00', NULL),
    (3, 1, '2026-01-01 00:00:00', NULL),
    (4, 1, '2026-01-01 00:00:00', NULL),
    (5, 1, '2026-01-01 00:00:00', '2026-09-25 14:20:00'),
    (6, 1, '2026-01-01 00:00:00', '2026-09-18 10:02:00');

INSERT INTO nivel_alerta (estado, descricao) VALUES
    ('Normal', 'Funcionamento dentro dos limites configurados'),
    ('Atenção', 'Métrica atingiu o primeiro limite configurado'),
    ('Crítico', 'Métrica atingiu o limite crítico configurado');

-- Estes registros formam o catálogo fixo de formas de medição.
INSERT INTO metrica_componente (nome, unidade_medida, especificacao) VALUES
    ('Uso', '%', 'Percentual de utilização'),
    ('Frequência', 'GHz', 'Frequência atual do processador'),
    ('Total', 'GB', 'Capacidade total'),
    ('Disponível', 'GB', 'Quantidade disponível'),
    ('Em uso', 'GB', 'Quantidade utilizada'),
    ('Download', 'MB', 'Dados recebidos pela rede'),
    ('Upload', 'MB', 'Dados enviados pela rede');

-- O tipo combina o recurso medido com uma das métricas fixas acima.
-- Os IDs abaixo seguem a ordem do INSERT de metrica_componente.
INSERT INTO tipo_componente (codigo, nome, fk_metrica_componente) VALUES
    ('CPU_USO', 'CPU', 1),
    ('CPU_FREQUENCIA', 'CPU', 2),
    ('RAM_USO', 'RAM', 1),
    ('RAM_TOTAL', 'RAM', 3),
    ('RAM_DISPONIVEL', 'RAM', 4),
    ('RAM_EM_USO', 'RAM', 5),
    ('DISCO_USO', 'Disco', 1),
    ('DISCO_TOTAL', 'Disco', 3),
    ('DISCO_DISPONIVEL', 'Disco', 4),
    ('DISCO_EM_USO', 'Disco', 5),
    ('REDE_RECEBIDA', 'Rede - Recebidos', 6),
    ('REDE_ENVIADA', 'Rede - Enviados', 7);

INSERT INTO componente (status_atividade, fk_tipo_componente)
SELECT 1, id FROM tipo_componente;

INSERT INTO maquina (
    nome, hostname, mac, ip, sistema_operacional,
    situacao, dtHr_ativacao, fk_empresa
) VALUES (
    'Servidor principal', 'SRV-193-CAD-01', '00:1A:2B:3C:4D:5E',
    '10.193.0.11', 'Ubuntu Server 22.04', 'ATIVA', CURRENT_TIMESTAMP, 2
);

-- A máquina de demonstração usa as doze opções fixas.
-- Os ids de configuracao_maquina seguem a ordem abaixo (1 a 12) e são usados
-- pelo Python (1 a 10) e pelo Java (11 e 12, rede).
INSERT INTO configuracao_maquina (fk_maquina, fk_componente) VALUES
    (1, 1),   -- id 1:  CPU Uso
    (1, 2),   -- id 2:  CPU Frequência
    (1, 3),   -- id 3:  RAM Uso
    (1, 4),   -- id 4:  RAM Total
    (1, 5),   -- id 5:  RAM Disponível
    (1, 6),   -- id 6:  RAM Em uso
    (1, 7),   -- id 7:  Disco Uso
    (1, 8),   -- id 8:  Disco Total
    (1, 9),   -- id 9:  Disco Disponível
    (1, 10),  -- id 10: Disco Em uso
    (1, 11),  -- id 11: Rede - Recebidos (Java)
    (1, 12);  -- id 12: Rede - Enviados  (Java)

-- Os limites variam por máquina; somente os catálogos acima são fixos.
-- Em nivel_alerta, o ID 2 representa Atenção e o ID 3 representa Crítico.
-- Total e Em uso (RAM e Disco) ficam sem limite.
INSERT INTO metrica_alerta (fk_configuracao_maquina, fk_nivel_alerta, limite) VALUES
    (1, 2, 70.0),   (1, 3, 90.0),    -- CPU Uso
    (2, 2, 3.5),    (2, 3, 4.2),     -- CPU Frequência
    (3, 2, 70.0),   (3, 3, 90.0),    -- RAM Uso
    (5, 2, 4.0),    (5, 3, 2.0),     -- RAM Disponível
    (7, 2, 75.0),   (7, 3, 90.0),    -- Disco Uso
    (9, 2, 50.0),   (9, 3, 20.0),    -- Disco Disponível
    (11, 2, 100.0), (11, 3, 200.0),  -- Rede recebida
    (12, 2, 100.0), (12, 3, 200.0);  -- Rede enviada

DELIMITER $$

-- Ativa uma máquina pendente. Sem UUID, empresa + MAC passa a ser a
-- identidade persistida da máquina depois que o código for consumido.
CREATE PROCEDURE ativar_maquina(
    IN p_codigo_ativacao VARCHAR(100),
    IN p_hostname VARCHAR(255),
    IN p_mac VARCHAR(17),
    IN p_ip VARCHAR(45),
    IN p_sistema_operacional VARCHAR(100)
)
BEGIN
    DECLARE v_maquina_id INT DEFAULT NULL;
    DECLARE v_empresa_id INT DEFAULT NULL;
    DECLARE v_mac_normalizado CHAR(17);

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_maquina_id = NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_mac_normalizado = UPPER(REPLACE(TRIM(p_mac), '-', ':'));

    IF p_codigo_ativacao IS NULL OR CHAR_LENGTH(TRIM(p_codigo_ativacao)) < 20 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Código de ativação inválido.';
    END IF;

    IF p_hostname IS NULL
        OR TRIM(p_hostname) = ''
        OR p_mac IS NULL
        OR v_mac_normalizado NOT REGEXP '^([0-9A-F]{2}:){5}[0-9A-F]{2}$'
        OR p_ip IS NULL
        OR TRIM(p_ip) = ''
        OR p_sistema_operacional IS NULL
        OR TRIM(p_sistema_operacional) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dados de identificação da máquina inválidos.';
    END IF;

    START TRANSACTION;

    SELECT m.id, m.fk_empresa
    INTO v_maquina_id, v_empresa_id
    FROM codigo_ativacao AS ca
    INNER JOIN maquina AS m ON m.id = ca.fk_maquina
    WHERE ca.codigo_hash = SHA2(TRIM(p_codigo_ativacao), 256)
        AND m.situacao = 'PENDENTE'
        AND ca.dtHr_expiracao >= CURRENT_TIMESTAMP
    LIMIT 1
    FOR UPDATE;

    IF v_maquina_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Código inexistente, utilizado ou expirado.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM maquina
        WHERE fk_empresa = v_empresa_id
            AND mac = v_mac_normalizado
            AND id <> v_maquina_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MAC já cadastrado nesta empresa.';
    END IF;

    UPDATE maquina
    SET hostname = TRIM(p_hostname),
        mac = v_mac_normalizado,
        ip = TRIM(p_ip),
        sistema_operacional = TRIM(p_sistema_operacional),
        situacao = 'ATIVA',
        dtHr_ativacao = CURRENT_TIMESTAMP
    WHERE id = v_maquina_id;

    DELETE FROM codigo_ativacao
    WHERE fk_maquina = v_maquina_id;

    COMMIT;

    SELECT id, nome, hostname, mac, ip,
        sistema_operacional AS sistemaOperacional, situacao
    FROM maquina
    WHERE id = v_maquina_id;

    SELECT
        cm.id AS configuracaoId,
        comp.id,
        tc.codigo,
        CONCAT(tc.nome, ' - ', mc.nome) AS nome,
        mc.unidade_medida AS unidadeMedida,
        MAX(CASE WHEN na.estado = 'Atenção' THEN ma.limite END) AS limiteAtencao,
        MAX(CASE WHEN na.estado = 'Crítico' THEN ma.limite END) AS limiteCritico
    FROM configuracao_maquina AS cm
    INNER JOIN componente AS comp ON comp.id = cm.fk_componente
    INNER JOIN tipo_componente AS tc ON tc.id = comp.fk_tipo_componente
    INNER JOIN metrica_componente AS mc ON mc.id = tc.fk_metrica_componente
    INNER JOIN metrica_alerta AS ma ON ma.fk_configuracao_maquina = cm.id
    INNER JOIN nivel_alerta AS na ON na.id = ma.fk_nivel_alerta
    WHERE cm.fk_maquina = v_maquina_id
        AND cm.ativa = 1
        AND comp.status_atividade = 1
    GROUP BY cm.id, comp.id, tc.codigo, tc.nome, mc.nome, mc.unidade_medida
    ORDER BY tc.nome, mc.nome;
END$$

DELIMITER ;

-- Consulta demonstrativa das capturas usando o catálogo restaurado.
SELECT
    c.id AS capturaId,
    maq.nome AS maquina,
    tc.nome AS componente,
    mc.nome AS metrica,
    c.valor,
    mc.unidade_medida AS unidade,
    c.dtHr
FROM captura AS c
INNER JOIN configuracao_maquina AS cm ON cm.id = c.fk_configuracao_maquina
INNER JOIN maquina AS maq ON maq.id = cm.fk_maquina
INNER JOIN componente AS comp ON comp.id = cm.fk_componente
INNER JOIN tipo_componente AS tc ON tc.id = comp.fk_tipo_componente
INNER JOIN metrica_componente AS mc ON mc.id = tc.fk_metrica_componente
ORDER BY c.dtHr;