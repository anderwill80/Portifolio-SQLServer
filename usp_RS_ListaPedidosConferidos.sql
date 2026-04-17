/*
====================================================================================================================================================================================
WREL155 - Lista de pedidos conferidos
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
06/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;
	- Filtros por empresa da tabela nos selects;
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_ListaPedidosConferidos]
	@empcod smallint,
	@data datetime,
	@horai char(8),
	@horaf char(8),
	@pedidos varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declaracoes das variaveis
	DECLARE @codigoEmpresa smallint, @DatConf datetime, @HoraIni char(8), @HoraFin char(8), @PedConf varchar(500),
			@empresaTBS055 smallint, @empresaTBS004 smallint;

	SET @codigoEmpresa = @empcod;
	SET @DatConf = @data;
	SET @HoraIni = @horai;
	SET @HoraFin = @horaf;
	SET @PedConf = @pedidos;

	-- Uso da função fSplit, para obter multivalores para a clausula IN()
	If object_id('TempDB.dbo.#PEDIDOS') is not null
		DROP TABLE #PEDIDOS;

    select elemento as [pedido]
	Into #PEDIDOS
    From fSplit(@PedConf, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS055', @empresaTBS055 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


	-- Script final

	select pedido
		   ,st_pendente
		   ,st_reservado
		   ,st_nf
		   ,count(*) as itens
		   ,conferente
		   ,vendedor
	from (
			select
			PRPNUM as pedido
			,subString(PRPUSUCNF,21,25) as conferente
			,case when sum(PRPQTDREA+PRPQTDREM) > 0 then 'X' else '' end as st_pendente
			,case when sum(PRPNFENUM+PRPQTDREA+PRPQTDREM) = 0 then 'X' else '' end as st_reservado
			,case when sum(PRPNFEQTD) > 0 then 'X' else '' end as st_nf
			,PRPITEM
			,count(*) as itens
			,(select VENNOM from TBS004 v with (nolock) where VENEMPCOD = @empresaTBS004 AND v.VENCOD = p.VENCOD) as vendedor
	from TBS058 r with (nolock)
	inner join TBS055 p with (nolock)
	on p.PDVEMPCOD  = @empresaTBS055 AND p.PDVEMPCOD=r.PRPEMP and p.PDVNUM=r.PRPNUM  
	WHERE 
	PRPEMP = @empresaTBS055
	and r.PRPSIT='R'
	and r.PRPQTDCONF > 0
	and convert(date,Left(r.PRPUSUCNF,10))= @DatConf
	and subString(r.PRPUSUCNF,12,8) between @HoraIni and @HoraFin
	and r.PRPNUM in(SELECT pedido FROM #PEDIDOS)

	group by r.PRPNUM, r.PRPUSUCNF, r.PRPITEM, p.VENCOD) tab
	group by pedido
			  ,st_pendente
			  ,st_reservado
			  ,st_nf
			  ,conferente
			  ,conferente
			  ,vendedor
	 order by pedido
END
