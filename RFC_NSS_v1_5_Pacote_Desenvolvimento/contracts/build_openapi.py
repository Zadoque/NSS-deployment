"""Gera o contrato OpenAPI 3.1 de referência do RFC-NSS 1.5."""
from __future__ import annotations
from pathlib import Path
import yaml

ROOT = Path(__file__).parent
id_schema = {'type':'string','format':'uuid'}
str_schema = {'type':'string'}
def ref(name): return {'$ref':f'#/components/schemas/{name}'}
def prop(name, typ='string', **kw):return dict(type=typ,description=name,**kw)
def obj(props,required=()):return {'type':'object','properties':props,'required':list(required)}
def arr(schema):return {'type':'array','items':schema}
def schema_ref(name):return {'$ref':f'#/components/schemas/{name}'}
error_codes={'400':'Bad Request','401':'Unauthenticated','403':'Forbidden','404':'Not Found','409':'Conflict','410':'Gone','413':'Payload Too Large','422':'Unprocessable Entity','429':'Too Many Requests','500':'Internal Server Error','503':'Service Unavailable'}
def response(status, schema=None,description=None,content_type='application/json'):
    res={'description':description or error_codes.get(str(status),'Resultado')}
    if schema:res['content']={content_type:{'schema':schema}}
    return res
problem=response(400,ref('Problem'),'Erro uniforme', 'application/problem+json')
def responses(code=200, schema=None,extra=(),description=None):
    result={str(code):response(code,schema,description)}
    for s in extra:result[str(s)]={'$ref':f'#/components/responses/Error{str(s)}'}
    return result

def reqbody(schema,required=True,ctype='application/json'):
    return {'required':required,'content':{ctype:{'schema':schema}}}
def header(name,required=False,description=''):
    return {'name':name,'in':'header','required':required,'description':description,'schema':{'type':'string'}}
def query(name,required=False,type='string',description='',**extra):
    return {'name':name,'in':'query','required':required,'description':description,'schema':{'type':type,**extra}}
def path(name,type='string'):
    return {'name':name,'in':'path','required':True,'schema':{'type':type}}
IDEMP=header('Idempotency-Key',True,'UUID v4. Escopo actor/rota/chave, fingerprint e retenção por 24 h; conflito 409.')
MATCH=header('If-Match',True,'ETag da versão do recurso; divergência 409.')
COMMON_PAGE=[query('page',type='integer',minimum=0,description='Começa em zero.'),query('size',type='integer',minimum=1,maximum=20,description='Tamanho máximo 20.')]
AUTH='BearerJWT'
P={}
def op(route,method,tag,summary,*,req=None,result=None,code=200,extra=('400','401','403','409','422','503'),params=(),public=False,roles=None,permission=None,ct='application/json',description=None):
    item={'tags':[tag],'summary':summary,'operationId':(method+'_'+route.strip('/').replace('/','_').replace('{','').replace('}','').replace('-','_')).strip('_'),'responses':responses(code,result,extra,description)}
    if req is not None:item['requestBody']=reqbody(req,ctype=ct)
    if params:item['parameters']=list(params)
    if public:item['security']=[]
    else:item['security']=[{AUTH:[]}]
    if roles:item['x-roles']=roles
    if permission:item['x-required-permission']=permission
    if description:item['description']=description
    P.setdefault(route,{})[method.lower()]=item

schemas={
'Problem':obj({'type':str_schema,'title':str_schema,'status':{'type':'integer'},'detail':str_schema,'instance':str_schema,'code':str_schema,'requestId':str_schema,'fieldErrors':arr(obj({'field':str_schema,'message':str_schema})),'retryAfterSeconds':{'type':'integer','minimum':0}},['type','title','status','code','requestId']),
'Id':id_schema,
'UserSummary':obj({'id':id_schema,'displayName':str_schema,'email':{'type':'string','format':'email'},'roles':arr(str_schema),'permissions':arr(str_schema),'accountVersion':{'type':'integer'},'active':{'type':'boolean'}},['id','roles','permissions','active']),
'AuthLogin':obj({'email':{'type':'string','format':'email'},'password':{'type':'string'},'replaceExistingSession':{'type':'boolean'}},['email','password']),
'AuthResult':obj({'accessToken':str_schema,'tokenType':{'type':'string','const':'Bearer'},'expiresIn':{'type':'integer','example':900},'user':ref('UserSummary')},['accessToken','tokenType','expiresIn','user']),
'StepUpInput':obj({'currentPassword':str_schema},['currentPassword']),
'StepUpResult':obj({'proof':str_schema,'expiresInSeconds':{'type':'integer','example':300}},['proof']),
'AccessRequest':obj({'name':{'type':'string','minLength':2,'maxLength':150},'email':{'type':'string','format':'email'},'reason':{'type':'string','minLength':10,'maxLength':4000},'requestedRole':str_schema,'reviewConfirmed':{'type':'boolean'},'privacyNoticeAcknowledged':{'type':'boolean'}},['name','email','reason','requestedRole','reviewConfirmed','privacyNoticeAcknowledged']),
'Accepted':obj({'accepted':{'type':'boolean'},'message':str_schema,'trackingHint':str_schema},['accepted','message']),
'AccessDecision':obj({'decision':{'type':'string','enum':['APPROVE','REJECT']},'reason':str_schema,'targetRoles':arr(str_schema)},['decision']),
'AccessRequestStatus':obj({'id':id_schema,'status':{'type':'string','enum':['AWAITING_EMAIL','PENDING_REVIEW','APPROVED','REJECTED','EXPIRED']},'createdAt':{'type':'string','format':'date-time'},'emailVerifiedAt':{'type':['string','null'],'format':'date-time'}},['id','status']),
'RoleChange':obj({'role':str_schema,'reason':str_schema,'stepUpProof':str_schema},['role','reason']),
'GrantChange':obj({'permission':{'type':'string','enum':['map.human.view','map.animal.view']},'reason':str_schema,'clinicId':id_schema},['permission','reason']),
'Clinic':obj({'id':id_schema,'name':str_schema,'municipalityIbge':{'type':'string','pattern':'^[0-9]{7}$'},'status':{'type':'string','enum':['ACTIVE','INACTIVE']},'address':str_schema,'version':{'type':'integer'}},['id','name','municipalityIbge','status']),
'ClinicCreate':obj({'name':{'type':'string','minLength':2},'municipalityIbge':{'type':'string','pattern':'^[0-9]{7}$'},'postalCode':{'type':'string','pattern':'^[0-9]{8}$'},'address':str_schema,'cnpj':str_schema,'source':str_schema},['name','municipalityIbge','source']),
'ClinicAgentAssign':obj({'userId':{'type':'integer'},'reason':str_schema},['userId','reason']),
'ClinicInvitation':obj({'email':{'type':'string','format':'email'},'reason':str_schema},['email']),
'InvitationAccept':obj({'token':str_schema},['token']),
'VetNotificationInput':obj({'clinicId':id_schema,'notificationDate':{'type':['string','null'],'format':'date'},'speciesCode':{'type':'integer','enum':[0,1,2]},'sexCode':{'type':'string','enum':['M','F','i']},'castrationCode':{'type':'integer','enum':[0,1,2]},'ageValue':{'type':['number','null'],'minimum':0},'ageUnit':{'type':'string','enum':['YEARS','MONTHS','UNKNOWN']},'ageUnknownReason':str_schema,'breedName':str_schema,'mixedBreed':{'type':'boolean'},'residenceMunicipalityIbge':{'type':'string','pattern':'^[0-9]{7}$'},'residenceTerritoryCode':str_schema,'residenceTerritorySource':str_schema,'sourceDeclaration':{'type':'boolean'}},['clinicId','speciesCode','sexCode','castrationCode','ageUnit','sourceDeclaration']),
'VetNotification':obj({'id':id_schema,'clinicId':id_schema,'status':{'type':'string','enum':['SUBMITTED','UNDER_REVIEW','VALIDATED','REJECTED']},'protocol':str_schema,'createdAt':{'type':'string','format':'date-time'},'dataVersion':{'type':'integer'},'sourceDataset':str_schema},['id','clinicId','status','createdAt']),
'VetCorrection':obj({'kind':{'type':'string','enum':['RECTIFICATION','CANCELLATION']},'reason':{'type':'string','minLength':10},'correctedData':ref('VetNotificationInput')},['kind','reason']),
'MunicipalUpload':obj({'id':id_schema,'municipalityIbge':str_schema,'disease':str_schema,'competence':str_schema,'sha256':str_schema,'status':{'type':'string','enum':['RECEIVING','VALIDATING','VALID','QUARANTINED','REJECTED','SUPERSEDED']},'supersedesUploadId':id_schema,'effectiveLimitBytes':{'type':'integer'},'reportUrl':str_schema},['id','municipalityIbge','sha256','status']),
'UploadValidation':obj({'decision':{'type':'string','enum':['ACCEPT','REJECT','QUARANTINE']},'reason':str_schema},['decision','reason']),
'PostInput':obj({'title':{'type':'string','minLength':3},'summary':str_schema,'content':ref('RichDocument'),'slug':str_schema,'coverAssetId':id_schema,'creditMode':str_schema},['title','content']),
'RichDocument':obj({'schemaVersion':{'type':'integer','const':1},'type':{'type':'string','const':'doc'},'content':arr({'type':'object','additionalProperties':True})},['schemaVersion','type','content']),
'Post':obj({'id':id_schema,'title':str_schema,'slug':str_schema,'summary':str_schema,'state':str_schema,'publishedAt':{'type':['string','null'],'format':'date-time'},'version':{'type':'integer'},'content':ref('RichDocument')},['id','title','slug','state']),
'PublishAction':obj({'reason':str_schema,'version':{'type':'integer'}},['version']),
'Bulletin':obj({'id':id_schema,'disease':str_schema,'competence':str_schema,'territoryCode':str_schema,'status':{'type':'string','enum':['PENDING_REVIEW','PUBLISHED','REJECTED','SUPERSEDED','UNPUBLISHED']},'sourceFingerprint':str_schema,'sourceDataset':str_schema,'createdAt':{'type':'string','format':'date-time'},'version':{'type':'integer'},'disclaimer':str_schema},['id','disease','competence','status','sourceFingerprint']),
'BulletinAction':obj({'decision':{'type':'string','enum':['APPROVE','REJECT']},'reason':str_schema,'expectedVersion':{'type':'integer'}},['decision','expectedVersion']),
'Coverage':obj({'status':{'type':'string','enum':['AVAILABLE','PARTIAL','UNAVAILABLE']},'eligibleRecords':{'type':'integer','minimum':0},'mappedRecords':{'type':'integer','minimum':0},'unknownTerritoryRecords':{'type':'integer','minimum':0}},['status']),
'MapItem':obj({'territoryCode':str_schema,'name':str_schema,'notificationsTotal':{'type':'integer','minimum':0}},['territoryCode','notificationsTotal']),
'AnimalEpidemiology':obj({'metric':{'type':'string','const':'notifications'},'disease':str_schema,'sourceDataset':{'type':'string','enum':['ESPORO_HISTORICAL_GABRIEL','VET_WEB_VERIFIED','VET_NOTIFICATION_CLINICAL']},'publicationFingerprint':str_schema,'publishedAt':{'type':['string','null'],'format':'date-time'},'definitionVersion':str_schema,'geographicBasis':str_schema,'coverage':ref('Coverage'),'items':arr(ref('MapItem')),'disclaimer':str_schema},['metric','sourceDataset','publicationFingerprint','definitionVersion','geographicBasis','coverage','items']),
'HumanEpidemiology':obj({'metric':{'type':'string','const':'notifications'},'geography':str_schema,'coverage':ref('Coverage'),'publicationFingerprint':str_schema,'publishedAt':{'type':'string','format':'date-time'},'items':arr(ref('MapItem'))},['metric','geography','coverage','items']),
'PublicationMetadata':obj({'sourceDataset':str_schema,'publicationFingerprint':str_schema,'publishedAt':{'type':'string','format':'date-time'},'coverage':ref('Coverage'),'availableYears':arr({'type':'integer'}),'availableMonthsByYear':{'type':'object','additionalProperties':arr({'type':'integer'})},'municipalityOnlyScopes':arr({'type':'object','additionalProperties':True})},['sourceDataset','publicationFingerprint','coverage']),
'CacheEpochs':obj({'posts':{'type':'integer','minimum':1},'bulletins':{'type':'integer','minimum':1},'institutional':{'type':'integer','minimum':1}},['posts','bulletins','institutional']),
'AboutPage':obj({'mission':str_schema,'description':str_schema,'institutions':arr(obj({'name':str_schema,'level':{'type':'integer'},'logoAssetId':id_schema,'officialUrl':str_schema},['name','level'])),'team':arr(obj({'displayName':str_schema,'role':str_schema,'bio':str_schema,'socialLinks':arr(str_schema),'visible':{'type':'boolean'}},['displayName','role'])),'revision':{'type':'integer'}},['mission','institutions','team','revision']),
'PostalAddress':obj({'postalCode':str_schema,'street':str_schema,'neighborhood':str_schema,'city':str_schema,'state':str_schema,'source':str_schema},['postalCode']),
'AuditEvent':obj({'id':id_schema,'actorId':str_schema,'action':str_schema,'targetType':str_schema,'targetId':str_schema,'occurredAt':{'type':'string','format':'date-time'},'requestId':str_schema},['id','action','occurredAt'])
}

def page_of(name):return obj({'items':arr(ref(name)),'page':{'type':'integer'},'size':{'type':'integer'},'totalElements':{'type':'integer'},'totalPages':{'type':'integer'},'hasNext':{'type':'boolean'}},['items','page','size','totalElements','totalPages','hasNext'])
for name,item in [('PostPage','Post'),('BulletinPage','Bulletin'),('ClinicPage','Clinic'),('UploadPage','MunicipalUpload'),('AccessRequestPage','AccessRequestStatus'),('AuditPage','AuditEvent'),('VetNotificationPage','VetNotification')]:schemas[name]=page_of(item)

op('/api/v1/auth/login','POST','Autenticação','Efetuar login e criar refresh cookie',req=ref('AuthLogin'),result=ref('AuthResult'),public=True,extra=('400','401','409','429','503'))
op('/api/v1/auth/refresh','POST','Autenticação','Rotacionar refresh HttpOnly e obter JWT',result=ref('AuthResult'),public=True,extra=('401','409','429','503'))
op('/api/v1/auth/logout','POST','Autenticação','Revogar sessão atual e remover cookie',code=204,extra=('401','503'))
op('/api/v1/auth/step-up','POST','Autenticação','Reconfirmar senha para ações críticas por 5 minutos',req=ref('StepUpInput'),result=ref('StepUpResult'),extra=('400','401','403','429','503'))
op('/api/v1/users/me','GET','Identidade','Consultar identidade e permissões efetivas',result=ref('UserSummary'),extra=('401','503'))
op('/api/v1/users/{userId}/roles','POST','Identidade','Conceder papel após checagem transacional do último chefe',req=ref('RoleChange'),result=ref('UserSummary'),params=[path('userId','integer'),IDEMP],roles=['CHEFE_GERAL','ADMINISTRADOR'])
op('/api/v1/users/{userId}/roles/{role}','DELETE','Identidade','Revogar papel com lock, step-up e auditoria',result=ref('UserSummary'),params=[path('userId','integer'),path('role'),IDEMP],roles=['CHEFE_GERAL','ADMINISTRADOR'])
op('/api/v1/users/{userId}/grants','POST','Identidade','Conceder grant independente de mapa',req=ref('GrantChange'),result=ref('UserSummary'),params=[path('userId','integer'),IDEMP],roles=['CHEFE_GERAL','ADMINISTRADOR','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/users/{userId}/grants/{permission}','DELETE','Identidade','Revogar grant de mapa',result=ref('UserSummary'),params=[path('userId','integer'),path('permission'),IDEMP],roles=['CHEFE_GERAL','ADMINISTRADOR','AGENTE_EPIDEMIOLOGICO'])
op('/api/public/access-requests','POST','Solicitações','Receber pedido após segunda etapa de revisão',req=ref('AccessRequest'),result=ref('Accepted'),code=202,params=[IDEMP],public=True,extra=('400','409','422','429','503'))
op('/api/public/access-requests/verify','POST','Solicitações','Confirmar e-mail por token único e movê-lo à fila de aprovação',req=obj({'token':str_schema},['token']),result=ref('Accepted'),public=True,extra=('400','410','429','503'))
op('/api/public/access-requests/status','GET','Solicitações','Consultar protocolo com segredo separado e prazo',result=ref('AccessRequestStatus'),params=[query('protocol',True),query('secret',True)],public=True,extra=('400','404','410','429','503'))
op('/api/v1/access-requests','GET','Solicitações','Listar solicitações a decidir com escopo administrativo',result=ref('AccessRequestPage'),params=COMMON_PAGE,roles=['CHEFE_GERAL','ADMINISTRADOR'])
op('/api/v1/access-requests/{requestId}/decision','POST','Solicitações','Decidir uma única vez, associar usuário existente e notificar via outbox',req=ref('AccessDecision'),result=ref('AccessRequestStatus'),params=[path('requestId'),IDEMP],roles=['CHEFE_GERAL','ADMINISTRADOR'])
op('/api/v1/clinics','POST','Clínicas','Cadastrar clínica sob gestão do agente ativo',req=ref('ClinicCreate'),result=ref('Clinic'),code=201,params=[IDEMP],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/clinics','GET','Clínicas','Listar clínicas permitidas ao usuário',result=ref('ClinicPage'),params=COMMON_PAGE,roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO','REPRESENTANTE_CLINICA'])
op('/api/v1/clinics/{clinicId}','GET','Clínicas','Consultar detalhes da clínica conforme vínculo ativo',result=ref('Clinic'),params=[path('clinicId')],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO','REPRESENTANTE_CLINICA'])
op('/api/v1/clinics/{clinicId}/status','POST','Clínicas','Ativar ou inativar clínica e revogar operações futuras',req=obj({'status':{'type':'string','enum':['ACTIVE','INACTIVE']},'reason':str_schema},['status','reason']),result=ref('Clinic'),params=[path('clinicId'),MATCH,IDEMP],roles=['CHEFE_GERAL'])
op('/api/v1/clinics/{clinicId}/agents','POST','Clínicas','Adicionar gestor ativo em relação N:M',req=ref('ClinicAgentAssign'),code=204,params=[path('clinicId'),IDEMP],roles=['CHEFE_GERAL'])
op('/api/v1/clinics/{clinicId}/agents/{userId}','DELETE','Clínicas','Revogar gestor sem desamparar a clínica',code=204,params=[path('clinicId'),path('userId','integer'),IDEMP],roles=['CHEFE_GERAL'])
op('/api/v1/clinics/{clinicId}/invitations','POST','Clínicas','Convidar representante com expiração de 72 horas',req=ref('ClinicInvitation'),result=ref('Accepted'),code=202,params=[path('clinicId'),IDEMP],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/clinics/invitations/accept','POST','Clínicas','Aceitar vínculo após validação da clínica e do usuário',req=ref('InvitationAccept'),result=ref('Clinic'),params=[IDEMP])
op('/api/v1/clinics/{clinicId}/members/{userId}','DELETE','Clínicas','Revogar vínculo clínico preservando histórico',code=204,params=[path('clinicId'),path('userId','integer'),IDEMP],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/animal/notifications','POST','Veterinária','Submeter notificação da clínica selecionada sem entrada direta na Gold',req=ref('VetNotificationInput'),result=ref('VetNotification'),code=201,params=[IDEMP],roles=['REPRESENTANTE_CLINICA'],description='Valida vínculo ativo na clínica no começo e no commit; recibo sem dados clínicos. Proíbe Agente gestor sem papel de representante.')
op('/api/v1/animal/notifications','GET','Veterinária','Consultar notificações autorizadas da clínica',result=ref('VetNotificationPage'),params=[query('clinicId',True),*COMMON_PAGE],roles=['REPRESENTANTE_CLINICA','AGENTE_EPIDEMIOLOGICO','CHEFE_GERAL'])
op('/api/v1/animal/notifications/{notificationId}/corrections','POST','Veterinária','Retificar ou cancelar via evento imutável',req=ref('VetCorrection'),result=ref('VetNotification'),params=[path('notificationId'),IDEMP],roles=['REPRESENTANTE_CLINICA','CHEFE_GERAL'])
op('/api/v1/municipal/uploads','POST','Municípios','Receber planilha CSV/XLS/XLSX em streaming com limite de admissão',req=obj({'municipalityIbge':str_schema,'disease':str_schema,'competence':str_schema,'file':{'type':'string','format':'binary'},'supersedesUploadId':id_schema,'sourceDeclaration':{'type':'boolean'}},['municipalityIbge','disease','competence','file','sourceDeclaration']),result=ref('MunicipalUpload'),code=201,params=[IDEMP],roles=['REPRESENTANTE_MUNICIPAL'],ct='multipart/form-data',extra=('400','401','403','409','413','422','429','503'))
op('/api/v1/municipal/uploads','GET','Municípios','Listar envios do representante ou fila do Analista',result=ref('UploadPage'),params=[query('municipalityIbge'),*COMMON_PAGE],roles=['REPRESENTANTE_MUNICIPAL','ANALISTA_DADOS','CHEFE_GERAL'])
op('/api/v1/municipal/uploads/{uploadId}','GET','Municípios','Consultar upload, digest, status e relatório',result=ref('MunicipalUpload'),params=[path('uploadId')],roles=['REPRESENTANTE_MUNICIPAL','ANALISTA_DADOS','CHEFE_GERAL'])
op('/api/v1/municipal/uploads/{uploadId}/validation','POST','Municípios','Validar ou colocar arquivo em quarentena',req=ref('UploadValidation'),result=ref('MunicipalUpload'),params=[path('uploadId'),IDEMP],roles=['ANALISTA_DADOS','CHEFE_GERAL'])
op('/api/v1/municipal/uploads/{uploadId}/download','GET','Municípios','Download auditado de arquivo permitido (quarentena exige ação especial)',result={'type':'string','format':'binary'},params=[path('uploadId')],roles=['ANALISTA_DADOS','CHEFE_GERAL'],extra=('400','401','403','404','409','503'))
op('/api/v1/posts','POST','Editorial','Criar pauta e rascunho JSONB schemaVersion 1',req=ref('PostInput'),result=ref('Post'),code=201,params=[IDEMP],roles=['ESCRITOR','ESCRITOR_CHEFE'])
op('/api/v1/posts/{postId}','PATCH','Editorial','Editar revisão única com ETag e controle de autoria',req=ref('PostInput'),result=ref('Post'),params=[path('postId'),MATCH],roles=['ESCRITOR','ESCRITOR_CHEFE'])
op('/api/v1/posts/{postId}/submit','POST','Editorial','Enviar rascunho para revisão',req=ref('PublishAction'),result=ref('Post'),params=[path('postId'),IDEMP],roles=['ESCRITOR','ESCRITOR_CHEFE'])
op('/api/v1/posts/{postId}/review','POST','Editorial','Solicitar alterações, rejeitar ou publicar com histórico',req=obj({'decision':{'type':'string','enum':['REQUEST_CHANGES','REJECT','PUBLISH']},'reason':str_schema,'version':{'type':'integer'}},['decision','version']),result=ref('Post'),params=[path('postId'),IDEMP],roles=['ESCRITOR_CHEFE'])
op('/api/v1/posts/{postId}/unpublish','POST','Editorial','Despublicar notícia e bloquear mídia exclusiva na mesma mudança lógica',req=ref('PublishAction'),result=ref('Post'),params=[path('postId'),IDEMP],roles=['ESCRITOR_CHEFE'])
op('/api/public/posts','GET','Portal público','Listar somente notícias publicadas',result=ref('PostPage'),params=COMMON_PAGE,public=True,extra=('400','429','503'))
op('/api/public/posts/{slug}','GET','Portal público','Ler revisão publicada da notícia, 404 quando retirada',result=ref('Post'),params=[path('slug')],public=True,extra=('400','404','429','503'))
op('/api/public/search','GET','Portal público','Busca FTS no conteúdo publicado, com acentos',result=obj({'posts':arr(ref('Post')),'bulletins':arr(ref('Bulletin')),'page':{'type':'integer'},'size':{'type':'integer'},'totalElements':{'type':'integer'},'totalPages':{'type':'integer'},'hasNext':{'type':'boolean'}},['posts','bulletins','page','size','totalElements','totalPages','hasNext']),params=[query('q',True,description='Mínimo 2 caracteres, máximo 100.'),query('type',description='posts|bulletins|all'),query('from'),query('to'),*COMMON_PAGE],public=True,extra=('400','429','503'))
op('/api/public/media/{assetId}','GET','Portal público','Servir mídia apenas se existir referência pública ativa',result={'type':'string','format':'binary'},params=[path('assetId')],public=True,extra=('400','404','429','503'))
op('/api/v1/bulletins','GET','Boletins','Listar minutas e versões sob autorização',result=ref('BulletinPage'),params=[query('disease'),query('competence'),*COMMON_PAGE],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/bulletins/{bulletinId}/decision','POST','Boletins','Aprovação única sob lock, delegação e fingerprint vigente',req=ref('BulletinAction'),result=ref('Bulletin'),params=[path('bulletinId'),IDEMP],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'])
op('/api/v1/bulletins/{bulletinId}/unpublish','POST','Boletins','Retirar versão e manter current_published_version_id null',req=ref('PublishAction'),result=ref('Bulletin'),params=[path('bulletinId'),IDEMP],roles=['CHEFE_GERAL'])
op('/api/public/bulletins','GET','Portal público','Listar apenas boletins publicados',result=ref('BulletinPage'),params=COMMON_PAGE,public=True,extra=('400','429','503'))
op('/api/public/bulletins/{bulletinId}','GET','Portal público','Exibir boletim com proveniência e aviso epidemiológico',result=ref('Bulletin'),params=[path('bulletinId')],public=True,extra=('400','404','429','503'))
op('/api/v1/epidemiology/municipalities','GET','Epidemiologia humana','Municípios segundo unidade de notificação e publicação corrente',result=ref('HumanEpidemiology'),params=[query('disease',True),query('year',True,'integer'),query('month',True,'integer'),query('sex'),query('ageBand'),query('uf'),query('region')],permission='map.human.view')
op('/api/v1/epidemiology/districts','GET','Epidemiologia humana','Distritos nacionais; cobertura indisponível não é zero',result=ref('HumanEpidemiology'),params=[query('disease',True),query('year',True,'integer'),query('month',True,'integer'),query('municipality',True)],permission='map.human.view')
op('/api/v1/epidemiology/neighborhoods','GET','Epidemiologia humana','Bairros da unidade notificadora, inclusive categorias nominais não mapeadas',result=ref('HumanEpidemiology'),params=[query('disease',True),query('year',True,'integer'),query('month',True,'integer'),query('municipality',True),query('district',True)],permission='map.human.view')
op('/api/v1/epidemiology/metadata','GET','Epidemiologia humana','Ler metadados atuais do mesmo snapshot para cache de cliente',result=ref('PublicationMetadata'),params=[query('disease'),query('year','false'=='true','integer')],permission='map.human.view')
op('/api/v1/animal/epidemiology/summary','GET','Epidemiologia animal','Consultar fonte animal explicitamente selecionada sem somá-la à outra fonte',result=ref('AnimalEpidemiology'),params=[query('sourceDataset',True,description='ESPORO_HISTORICAL_GABRIEL, VET_WEB_VERIFIED ou VET_NOTIFICATION_CLINICAL'),query('competence'),query('speciesCode',type='integer')],permission='map.animal.view')
op('/api/v1/animal/epidemiology/neighborhoods','GET','Epidemiologia animal','Consultar apenas territórios animais verificados pela fonte',result=ref('AnimalEpidemiology'),params=[query('sourceDataset',True,description='VET_WEB_VERIFIED ou VET_NOTIFICATION_CLINICAL quando houver território comprovado'),query('competence')],permission='map.animal.view')
op('/api/v1/animal/epidemiology/metadata','GET','Epidemiologia animal','Consultar fingerprint, data de corte e completude animal',result=ref('PublicationMetadata'),params=[query('sourceDataset',True)],permission='map.animal.view')
op('/api/v1/epidemiology/export','GET','Epidemiologia humana','Exportar CSV agregada e metadados sob permissão de mapa',result={'type':'string','format':'binary'},params=[query('disease',True),query('year',True,'integer'),query('month',True,'integer'),query('geography',True)],permission='map.human.view')
op('/api/v1/animal/epidemiology/export','GET','Epidemiologia animal','Exportar CSV animal com fonte e cobertura',result={'type':'string','format':'binary'},params=[query('sourceDataset',True),query('competence')],permission='map.animal.view')
op('/api/public/about','GET','Portal público','Página Sobre e equipe na versão homologada',result=ref('AboutPage'),public=True,extra=('404','429','503'))
op('/api/v1/institutional/about','PUT','Institucional','Atualizar e publicar revisão da página Sobre por Chefe Geral',req=ref('AboutPage'),result=ref('AboutPage'),params=[MATCH],roles=['CHEFE_GERAL'])
op('/api/public/legal/{documentSlug}','GET','Portal público','Política de privacidade, termos e acessibilidade com versões',result=obj({'slug':str_schema,'html':str_schema,'revision':{'type':'integer'},'publishedAt':{'type':'string','format':'date-time'}},['slug','html','revision']),params=[path('documentSlug')],public=True,extra=('404','429','503'))
op('/api/v1/institutional/legal/{documentSlug}','PUT','Institucional','Publicar texto legal após aprovação jurídica',req=obj({'html':str_schema,'legalApprovalId':str_schema,'reason':str_schema},['html','legalApprovalId']),result=ref('Accepted'),params=[path('documentSlug'),MATCH],roles=['CHEFE_GERAL'])
op('/api/v1/addresses/postal-code/{postalCode}','GET','Endereços','Proxy controlado para CEP com cache PostgreSQL e fallback manual',result=ref('PostalAddress'),params=[path('postalCode')],roles=['CHEFE_GERAL','AGENTE_EPIDEMIOLOGICO'],extra=('400','401','403','404','429','503'))
op('/api/v1/audit/events','GET','Auditoria','Consultar trilha limitada ao nível do executor',result=ref('AuditPage'),params=[query('actorId'),query('action'),*COMMON_PAGE],roles=['CHEFE_GERAL','ADMINISTRADOR'])
op('/api/public/cache/epochs','GET','Portal público','Versões públicas persistidas em PostgreSQL para invalidação segura',result=ref('CacheEpochs'),public=True,extra=('429','503'))

# Idempotency-Key on a DELETE/POST is intentionally explicit and must be supported by the middleware.
components={'securitySchemes':{'BearerJWT':{'type':'http','scheme':'bearer','bearerFormat':'JWT'},'RefreshCookie':{'type':'apiKey','in':'cookie','name':'nss_refresh'}},'schemas':schemas,'responses':{f'Error{s}':response(s,ref('Problem'),title,'application/problem+json') for s,title in error_codes.items()}}
# Response 204 may not have body, valid.
spec={'openapi':'3.1.0','info':{'title':'NSS/UENF — API contratual consolidada','version':'1.5.0','description':'Contrato de desenvolvimento proposto pelo RFC-NSS-001 v1.5. Confirme rotas pré-existentes no contrato v1 e implemente novas rotas sem quebra retroativa. As operações dependentes de governança não estão homologadas para produção.'},'servers':[{'url':'https://nss.uenf.br','description':'URL institucional; produção condicionada a release gates'}],'tags':[{'name':name} for name in ['Autenticação','Identidade','Solicitações','Clínicas','Veterinária','Municípios','Editorial','Portal público','Boletins','Epidemiologia humana','Epidemiologia animal','Institucional','Endereços','Auditoria']],'paths':P,'components':components,'security':[{'BearerJWT':[]}]}
file=ROOT/'openapi-nss-v1.5.yaml'
file.write_text('# Gerado a partir de contracts/build_openapi.py — RFC-NSS-001 v1.5\n'+yaml.safe_dump(spec,allow_unicode=True,sort_keys=False,width=105),encoding='utf-8')
print('Generated:',file,'paths:',len(P),'operations:',sum(len(x) for x in P.values()),'schemas:',len(schemas))
