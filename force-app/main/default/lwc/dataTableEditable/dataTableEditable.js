import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecords from "@salesforce/apex/DemoDataTableEditable.getRecords";
import updateRecords from '@salesforce/apex/DataTableEditable.updateRecords';

import {loadStyle} from 'lightning/platformResourceLoader'
import COLORS from '@salesforce/resourceUrl/EditableDataTable'

export default class DataTableEditable extends LightningElement {

    columns;
    records=[];
    lastSavedData;
    error;
    wiredRecords;
    showSpinner = false;
    showTable = false;
    draftValues = [];
    //used to obtain the picklist as private children of datatable
    privateChildren = {}; 
    isCssLoaded = false

    // lazey loading attributes
    rowOffset = 0;
    @api rowLimit=50;
    isLoading = true;
    continueSearching =false;


    connectedCallback(){
        this.loadRelatedRecords();
        this.showTable = true;
        this.lastSavedData = this.records;
    }

    renderedCallback() {
        if (!this.isComponentLoaded) {
            window.addEventListener('click', (evt) => {
                this.handleClickOnWindow(evt);
            });
            this.isComponentLoaded = true;
        }

        if(this.isCssLoaded) return
        this.isCssLoaded = true
        loadStyle(this, COLORS).then(()=>{
            console.log("Loaded Successfully")
        }).catch(error=>{ 
            console.error("Error in loading the colors")
        })
    }

    disconnectedCallback() {
        window.removeEventListener('click', () => { });
    }

    handleClickOnWindow(context) {
        
        this.resetPopups('c-datatable-picklist', context);
        this.resetPopups('c-datatable-lookup', context);
    }

    
    resetPopups(markup, context) {
        let elementMarkup = this.privateChildren[markup];
        if (elementMarkup) {
            Object.values(elementMarkup).forEach((element) => {
                element.callbacks.reset(context);
            });
        }
    }


    async loadRelatedRecords(){
        this.showSpinner=true;
        let result;
        try {
          result = await getRecords({limitSize: this.rowLimit , offset : this.rowOffset});
          console.log('length'+result.datas.length);
          let updatedRecords= [...this.records, ...result.datas];
          this.records = updatedRecords;
          this.columns= result.columns;
          this.lastSavedData=this.records;
          this.isLoading = false;
          if(this.rowLimit && result.datas.length == this.rowLimit) {
            this.continueSearching=true;
        } else {
            this.continueSearching=false;

        }

        } catch (error) {
          result = undefined;
        }
        finally{
            this.showSpinner=false;
            this.showTable=true;
            this.lastSavedData=true;
            return this.records;
        }
    }


    // Event to register the datatable picklist and the lookup mark up.
    handleRegisterItem(event) {
        event.stopPropagation(); 
        const item = event.detail;
        if (!this.privateChildren.hasOwnProperty(item.name))
            this.privateChildren[item.name] = {};
        this.privateChildren[item.name][item.guid] = item;
    }


    handleCancel(event) {
        event.preventDefault();
        this.records = JSON.parse(JSON.stringify(this.lastSavedData));
        this.handleClickOnWindow('reset');
        this.draftValues = [];
    }
	
	handleCellChange(event) {
        event.preventDefault();
        this.updateDraftValues(event.detail.draftValues[0]);
    }

    handleValueChange(event) {        

        event.stopPropagation();
        let dataRecieved = event.detail.data;
        let updatedItem;
        if (dataRecieved.className) {
            updatedItem = {};
            updatedItem['Id']=dataRecieved.context;
            updatedItem[dataRecieved.name]=dataRecieved.value;
            this.setClasses(dataRecieved.context,dataRecieved.className,'slds-cell-edit slds-is-edited');
        }
        else{
            this.setClasses(dataRecieved.context, '', '');
        }
        this.updateDraftValues(updatedItem);
        this.updateDataValues(updatedItem);
    }

    updateDataValues(updateItem) {
        
        let copyData = JSON.parse(JSON.stringify(this.records));
        copyData.forEach((item) => {
            if (item.Id === updateItem.Id) {
                for (let field in updateItem) {
                    item[field] = updateItem[field];
                }
            }
        });
        this.records = [...copyData];
    }

    updateDraftValues(updateItem) {
        
        let draftValueChanged = false;
        let copyDraftValues = JSON.parse(JSON.stringify(this.draftValues));
        copyDraftValues.forEach((item) => {
            if (item.Id === updateItem.Id) {
                for (let field in updateItem) {
                    item[field] = updateItem[field];
                }
                draftValueChanged = true;
            }
        });
        if (draftValueChanged) {
            this.draftValues = [...copyDraftValues];
        } else {
            this.draftValues = [...copyDraftValues, updateItem];
        }
      
    }

    handleEdit(event) {
        event.preventDefault();
        let dataRecieved = event.detail.data;
        this.handleClickOnWindow(dataRecieved.context);
        if (dataRecieved.className) {
            this.setClasses(dataRecieved.context,dataRecieved.className,'slds-cell-edit');
            }
            else{
                this.setClasses(dataRecieved.context, '', '');
            }
    }

    setClasses(id, fieldName, fieldValue) {
        this.records = JSON.parse(JSON.stringify(this.records));
        this.records.forEach((detail) => {
            if (detail.Id === id) {
                detail[fieldName] = fieldValue;
            }
        });
    }

    async handleSave(event) {
        event.preventDefault();
        this.showSpinner = true;
        this.showTable = false;
        const updatedFields = event.detail.draftValues;
        this.draftValues = [];
        try {
            // Pass edited fields to the updateOpportunities Apex controller
            await updateRecords({ recordsforUpdate: updatedFields });
            this.showToast('Success', 'records updated successfully', 'success');
        } catch (error) {
            this.showToast('Error while updating or refreshing records', error.body.message , 'error');
            console.log('error:',error);
            this.showSpinner = false;
        }
        finally{
            //reload Opportunities after updating fields
            this.records = await this.loadRelatedRecords();
            
            this.showSpinner = false;
            this.showTable = true;
           
        }
    }

    showToast(title, message, variant){
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    /*
        lazy loading
    */

    loadMoreData(event) {
        if(this.continueSearching){
            this.isLoading = true;
            this.rowOffset = this.rowOffset + this.rowLimit;
            this.loadRelatedRecords()
                .then(()=> {
                    this.isLoading = false;
                });
        }
     }
}