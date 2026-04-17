/*
====================================================================================================================================================================================
Retorna quantidade da embalagem conforme codigo do produto informado, verifica na tabela de codigo de barras, e na tabela principal
se informado o interno + 2222/3333/4444
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
30/01/2026 WILLIAM
	- Alteracao para retornar 1 na quantidade de embalagem, quando encontrar produto, porém a embalagem que foi vendida no caixa foi excluida no Integros;
29/01/2026 WILLIAM
	- Alteracao para retornar 1 na quantidade de embalagem, quando nao encontrar produto;
14/01/2026 WILLIAM
	- Criacao;	
====================================================================================================================================================================================
*/
--CREATE PROC  [dbo].[usp_Get_EmbalagemProduto]
ALTER PROC  [dbo].[usp_Get_EmbalagemProduto]
	@pcodproduto VARCHAR(20),

	@pprocod VARCHAR(20) OUT,
	@pprodes varchar(60) OUT,
	@pstatus VARCHAR(1) OUT,
	@pum1 VARCHAR(2) OUT,
	@pqtdemb INT OUT,
	@pmarcod INT OUT,
	@pforcod INT OUT
AS 
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @PROCOD VARCHAR(20), @PRODES VARCHAR(60), @PROUM1 CHAR(2), @PROSTATUS char(1), @MARCOD INT, @FORCOD INT, @QTDEMB INT, @codproduto varchar(20);

	SET @codproduto = @pcodproduto;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	/*
		PASSO 1: Buscas no cadastro de cdigos de barras do produto
	*/	
	SELECT
		@PROCOD = CBPPROCOD,
		@PRODES = PRODES,
		@PROUM1 = PROUM1,
		@QTDEMB = CBPQTDEMB,
		@PROSTATUS = PROSTATUS,
		@MARCOD = MARCOD,
		@FORCOD = FORCOD
	FROM TBS0103 WITH (NOLOCK)	
	JOIN TBS010 ON CBPPROCOD = PROCOD
	WHERE 
		CBPCODBAR = @codproduto;	
	/*
		PASSO 2: Buscas no cadastro principal do produto, caso não tenha encontrado no passo 1
	*/
	IF @PROCOD IS NULL
	BEGIN		
		-- Se código encontrado nesse ponto, significa que foi recebido o código interno, retorna embalagem 1
		
		-- Busca pela PRIMEIRA unidade de medido: codigo
		PRINT 'BUSCANDO PRIMEIRA UM'
		SELECT
			@PROCOD = PROCOD,
			@PRODES = PRODES,
			@PROUM1 = PROUM1,
			@QTDEMB = 1,
			@PROSTATUS = PROSTATUS,
			@MARCOD = MARCOD,
			@FORCOD = FORCOD
		FROM TBS010 WITH (NOLOCK)
		WHERE 
			PROCOD = @codproduto;

		-- Busca pela SEGUNDA unidade de medido: codigo + 2222
		IF @PROCOD IS NULL
		BEGIN		
			-- Se encontrado, retorna embalagem 2
			PRINT 'BUSCANDO SEGUNDA UM'
			SELECT
				@PROCOD = PROCOD,
				@PRODES = PRODES,
				@PROUM1 = PROUM1,
				@QTDEMB = IIF(PROUM2QTD <= 0, 1, PROUM2QTD),
				@PROSTATUS = PROSTATUS,
				@MARCOD = MARCOD,
				@FORCOD = FORCOD
			FROM TBS010 WITH (NOLOCK)
			WHERE 
				RTRIM(PROCOD) + '2222' = @codproduto;

			-- Busca pela TERCEIRA unidade de medido: codigo + 3333
			IF @PROCOD IS NULL
			BEGIN		
				-- Se encontrado, retorna embalagem 3
				PRINT 'BUSCANDO TERCEIRA UM'
				SELECT
					@PROCOD = PROCOD,
					@PRODES = PRODES,
					@PROUM1 = PROUM1,
					@QTDEMB = IIF(PROUM3QTD <= 0, 1, PROUM3QTD),
					@PROSTATUS = PROSTATUS,
					@MARCOD = MARCOD,
					@FORCOD = FORCOD
				FROM TBS010 WITH (NOLOCK)
				WHERE 
					RTRIM(PROCOD) + '3333' = @codproduto;

				-- Busca pela QUARTA unidade de medido: codigo + 4444
				IF @PROCOD IS NULL
				BEGIN		
					-- Se encontrado, retorna embalagem 4
					PRINT 'BUSCANDO QUARTA UM'
					SELECT
						@PROCOD = PROCOD,
						@PRODES = PRODES,
						@PROUM1 = PROUM1,
						@QTDEMB = IIF(PROUM4QTD <= 0, 1, PROUM4QTD),
						@PROSTATUS = PROSTATUS,
						@MARCOD = MARCOD,
						@FORCOD = FORCOD
					FROM TBS010 WITH (NOLOCK)
					WHERE 
						RTRIM(PROCOD) + '4444' = @codproduto;
				END
			END
		END
	END

	-- Retorna dados
	SELECT 
		@pprocod = ISNULL(@PROCOD, ''), 
		@pprodes = ISNULL(@PRODES, ''), 
		@pum1 = ISNULL(@PROUM1, ''),
		@pqtdemb = ISNULL(@QTDEMB, 1), 
		@pstatus = ISNULL(@PROSTATUS, ''),
		@pmarcod = ISNULL(@MARCOD, 0), 
		@pforcod = ISNULL(@FORCOD, 0);
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END
