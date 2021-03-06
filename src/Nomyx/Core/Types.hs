{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TemplateHaskell    #-}
{-# LANGUAGE TypeFamilies       #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE TypeSynonymInstances      #-}
{-# LANGUAGE FlexibleInstances      #-}

module Nomyx.Core.Types (
   module Nomyx.Core.Types,
   module Nomyx.Core.Engine.Types)
   where

import           Control.Lens hiding (Indexable)
import           Data.Acid                           (AcidState)
import           Data.Aeson.TH                       (defaultOptions, deriveJSON)
import           Data.Data                           (Data)
import           Data.IxSet                          (ixFun, ixSet, Indexable(..), IxSet)
import           Data.SafeCopy                       (base, extension, deriveSafeCopy, Migrate(..))
import           Data.Time
import           Data.List
import           Data.Typeable
import           Data.Aeson
import           GHC.Generics (Generic)
import           Network.BSD
import           Nomyx.Language
import           Nomyx.Core.Engine
import           Nomyx.Core.Engine.Types


type PlayerPassword = String
type Port = Int
type CompileMsg = String

-- * Game structures

-- | Session contains all the game informations.
data Session = Session { _multi        :: Multi,
                         _acidProfiles :: AcidState ProfileDataState}

instance Show Session where
   show (Session m _) = show m

-- | A structure to hold the active games and players
data Multi = Multi { _gameInfos :: [GameInfo],
                     _mSettings :: Settings,
                     _mLibrary  :: Library}
                     deriving (Eq, Show, Typeable)

-- | Informations on a particular game
data GameInfo = GameInfo { _loggedGame     :: LoggedGame,
                           _ownedBy        :: Maybe PlayerNumber,
                           _forkedFromGame :: Maybe GameName,
                           _isPublic       :: Bool,
                           _startedAt      :: UTCTime}
                           deriving (Typeable, Show, Eq)

-- | Global settings
data Settings = Settings { _net           :: Network,      -- URL where the server is launched
                           _mailSettings  :: MailSettings, -- send mails or not
                           _adminPassword :: String,       -- admin password
                           _saveDir       :: FilePath,     -- location of the save file, profiles and uploaded files
                           _webDir        :: FilePath,     -- location of the website files
                           _sourceDir     :: FilePath,     -- location of the language files, for display on the web gui (from Nomyx-Language)
                           _watchdog      :: Int}          -- time in seconds before killing the compilation thread
                           deriving (Eq, Show, Read, Typeable)

-- | Network infos
data Network = Network {_host :: HostName,
                        _port :: Port}
                        deriving (Eq, Show, Read, Typeable)

data MailSettings = MailSettings {_sendMails :: Bool,
                                  _mailHost  :: String,
                                  _mailLogin :: String,
                                  _mailPass  :: String}
                                  deriving (Eq, Show, Read, Typeable)

-- | The Library contains a list of rule templates together with their declarations
data Library = Library { _mTemplates :: [RuleTemplateInfo],
                         _mModules   :: [ModuleInfo]}
                         deriving (Eq, Ord, Typeable)

data RuleTemplateInfo = RuleTemplateInfo { _iRuleTemplate :: RuleTemplate,
                                           _iCompileMsg   :: CompileMsg}
                                           deriving (Eq, Show, Ord)

instance Show Library where
   show (Library ts ms) = "\n\n Library Templates = " ++ (intercalate "\n " $ map show ts) ++
                          "\n\n Library Modules = "   ++ (intercalate "\n " $ map show ms)


-- * Player settings

data ProfileDataState = ProfileDataState { profilesData :: IxSet ProfileData }
    deriving (Eq, Ord, Show, Typeable)

-- | 'ProfileData' contains player settings
data ProfileData =
    ProfileData { _pPlayerNumber   :: PlayerNumber, -- same as UserId
                  _pPlayerSettings :: PlayerSettings,
                  _pIsAdmin        :: Bool,
                  _pLibrary        :: Library}
                  deriving (Eq, Ord, Show, Typeable, Generic)

instance Indexable ProfileData where
      empty =  ixSet [ ixFun (\(ProfileData pn _ _ _) -> [pn])]

-- Settings of a single player
data PlayerSettings =
   PlayerSettings { _pPlayerName    :: PlayerName,
                    _mail           :: Maybe String,
                    _mailNewInput   :: Bool,
                    _mailSubmitRule :: Bool,
                    _mailNewOutput  :: Bool,
                    _mailConfirmed  :: Bool}
                    deriving (Eq, Show, Read, Data, Ord, Typeable, Generic)


$(deriveSafeCopy 1 'base ''PlayerSettings)
$(deriveSafeCopy 1 'base ''RuleTemplate)
$(deriveSafeCopy 1 'base ''ModuleInfo)
$(deriveSafeCopy 1 'base ''ProfileDataState)
$(deriveSafeCopy 1 'base ''RuleTemplateInfo)
$(deriveSafeCopy 2 'extension ''ProfileData)
$(deriveSafeCopy 2 'extension ''Library)


makeLenses ''Multi
makeLenses ''Library
makeLenses ''RuleTemplateInfo
makeLenses ''ModuleInfo
makeLenses ''GameInfo
makeLenses ''Settings
makeLenses ''Network
makeLenses ''PlayerSettings
makeLenses ''Session
makeLenses ''ProfileData
makeLenses ''MailSettings

$(deriveJSON defaultOptions ''Library)
$(deriveJSON defaultOptions ''RuleTemplateInfo)
$(deriveJSON defaultOptions ''GameInfo)
$(deriveJSON defaultOptions ''Multi)
$(deriveJSON defaultOptions ''Settings)
$(deriveJSON defaultOptions ''Network)
$(deriveJSON defaultOptions ''PlayerSettings)
$(deriveJSON defaultOptions ''ProfileData)
$(deriveJSON defaultOptions ''RuleInfo)
$(deriveJSON defaultOptions ''RuleStatus)
$(deriveJSON defaultOptions ''MailSettings)


instance ToJSON Rule where
   toJSON _ = object []

instance FromJSON Rule where
   parseJSON (Object _) = error "FromJSON"

-- * Migrations

-- | The Library conains a list of rule templates gether with their declarations
data LibraryV1_0 = LibraryV1_0 { _mTemplates1 :: [RuleTemplate],
                                 _mModules1   :: [ModuleInfo]}
                         deriving (Eq, Ord, Typeable, Show)
$(deriveSafeCopy 1 'base ''LibraryV1_0)

type LastRule = (RuleTemplate, String)
type CompileError = String

data LastUploadV1_0 = NoUpload
                | UploadSuccess
                | UploadFailure (FilePath, CompileError)
                deriving (Eq, Ord, Read, Show, Typeable, Data, Generic)
$(deriveSafeCopy 1 'base ''LastUploadV1_0)

-- | 'ProfileData' contains player settings
data ProfileDataV1_0 =
    ProfileDataV1_0 { _pPlayerNumber1   :: PlayerNumber, -- same as UserId
                  _pPlayerSettings1 :: PlayerSettings,
                  _pLastRule1       :: Maybe LastRule,
                  _pLastUpload1     :: LastUploadV1_0,
                  _pIsAdmin1        :: Bool,
                  _pLibrary1        :: LibraryV1_0}
                  deriving (Eq, Ord, Show, Typeable, Generic)
$(deriveSafeCopy 1 'base ''ProfileDataV1_0)

instance Migrate ProfileData where
     type MigrateFrom ProfileData = ProfileDataV1_0
     migrate (ProfileDataV1_0 pn set _ _ admin lib) = ProfileData pn set admin (migrate lib)

instance Migrate Library where
     type MigrateFrom Library = LibraryV1_0
     migrate (LibraryV1_0 tps ms) = Library (map (\tp -> RuleTemplateInfo tp "") tps) ms 
