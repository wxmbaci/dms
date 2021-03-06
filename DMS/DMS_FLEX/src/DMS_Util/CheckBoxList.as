////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (c) 2007 Josh Tynjala
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to 
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

package DMS_Util
{
	import com.bankcomm.DataDictContainer;
	import com.flextoolbox.controls.AdvancedList;
	import com.flextoolbox.controls.listClasses.*;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import mx.collections.CursorBookmark;
	import mx.collections.IViewCursor;
	import mx.controls.listClasses.IListItemRenderer;
	import mx.core.ClassFactory;
	import mx.core.IUIComponent;
	import mx.core.mx_internal;
	import mx.events.DragEvent;
	import mx.events.ListEvent;
	import mx.managers.DragManager;

	use namespace mx_internal;

	/**
	 * A List that contains CheckBoxes to indicate selection rather than a colored
	 * background. By default, multiple selection is allowed. Additionally, the ctrl key
	 * does not need to held down by the user to select multiple items. The default
	 * behavior for the shift key is unchanged.
	 *
	 * @author Josh Tynjala
	 */
	public class CheckBoxList extends AdvancedList
	{

		//----------------------------------
		//  Constructor
		//----------------------------------

		/**
		 * Constructor.
		 */
		public function CheckBoxList()
		{
			super();

			this.itemRenderer=new ClassFactory(CheckBoxListItemRenderer);
			this.allowMultipleSelection=true;
		}

		//----------------------------------
		//  Variables and Properties
		//----------------------------------

		private var _dict:Array=[];
		private var _dictName:String="";

		/**
		 *
		 * DataDict name setter<br />
		 * ????????????????????????
		 * @param value ??????????????????
		 *
		 * */
		public function set dict(value:String):void
		{
			if (value)
			{
				_dictName=value;
				_dict=DataDictContainer.Dictionary[Global.appName][value];
				dataProvider=_dict;
			}
		}

		/**
		 *
		 * DataDict name Getter<br />
		 * ????????????????????????
		 * @return String
		 *
		 * */
		public function get dict():String
		{
			return _dictName;
		}


		/**
		 * @private
		 */
		override protected function get dragImage():IUIComponent
		{
			var image:CheckBoxListItemDragProxy=new CheckBoxListItemDragProxy();
			image.owner=this;
			return image;
		}

		/**
		 * Gets the offset of the drag image for drag and drop.
		 */
		override protected function get dragImageOffsets():Point
		{
			var rendererToDrag:IListItemRenderer=this.indexToItemRenderer(this.indexToDrag);
			var offset:Point=new Point(rendererToDrag.x, rendererToDrag.y);

			return offset;
		}

		/**
		 * @private
		 * Force validation because the ListBase assumes the item renderers are created.
		 */
		override public function set selectedIndices(indices:Array):void
		{
			this.validateNow();
			super.selectedIndices=indices;
		}

		//----------------------------------
		//  Protected Methods
		//----------------------------------

		/**
		 * @private
		 */
		override protected function drawItem(renderer:IListItemRenderer, selected:Boolean=false, highlighted:Boolean=false, caret:Boolean=false, transition:Boolean=false):void
		{
			if (renderer) //sometimes renderer is null
			{
				renderer.enabled=this.isItemEnabled(renderer.data);
				super.drawItem(renderer, selected, highlighted && renderer.enabled, caret, transition);

			}
		}

		/**
		 * @private
		 */
		override protected function selectItem(renderer:IListItemRenderer, shiftKey:Boolean, ctrlKey:Boolean, transition:Boolean=true):Boolean
		{
			//since we have check boxes, selection needs to work a bit differently
			//so we're pretending that ctrlKey is always down
			return super.selectItem(renderer, shiftKey, true, transition);
		}

		/**
		 * @private
		 * The index of the last "touched" item in the list.
		 */
		mx_internal var indexToDrag:int;

		/**
		 * @private
		 */
		override protected function mouseDownHandler(event:MouseEvent):void
		{
			if (!enabled || !selectable)
				return;

			var item:IListItemRenderer=this.mouseEventToItemRenderer(event);
			if (item && item.enabled)
			{
				this.indexToDrag=this.itemRendererToIndex(item);
			}
			else
				this.indexToDrag=-1;

			super.mouseDownHandler(event);
		}

		/**
		 * @private
		 */
		override protected function addDragData(dragSource:Object):void // actually a DragSource
		{
			if (this.indexToDrag < 0)
				return;

			var dragData:Object=this.collection[this.indexToDrag];
			dragSource.addData([dragData], this.dragFormat);
		}

		/**
		 * @private
		 */
		override protected function dragDropHandler(event:DragEvent):void
		{
			if (event.isDefaultPrevented())
				return;

			hideDropFeedback(event);

			if (event.dragSource.hasFormat(this.dragFormat))
			{
				if (!dataProvider)
				{
					// Create an empty collection to drop items into.
					dataProvider=[];
				}

				var items:Array=event.dragSource.dataForFormat(this.dragFormat) as Array;
				var indices:Array=this.selectedIndices.concat();
				var dropIndex:int=calculateDropIndex(event);
				if (event.action == DragManager.MOVE && dragMoveEnabled)
				{
					if (event.dragInitiator == this)
					{
						collectionIterator.seek(CursorBookmark.FIRST, this.indexToDrag);
						collectionIterator.remove();

						//remove the selection for the item we just removed
						indices.splice(indices.indexOf(this.indexToDrag), 1);

						//update the remaining selected indices
						var selectedCount:int=indices.length;
						for (i=0; i < selectedCount; i++)
						{
							var currentIndex:int=indices[i];
							if (currentIndex >= dropIndex && currentIndex < this.indexToDrag)
								indices[i]=currentIndex + 1;
							else if (currentIndex > this.indexToDrag && currentIndex < dropIndex)
								indices[i]=currentIndex - 1;
						}

						if (this.indexToDrag < dropIndex)
						{
							dropIndex--;
						}
					}
					else
					{
						//increase the indices in the positions after the dropped item
						selectedCount=indices.length;
						for (i=0; i < selectedCount; i++)
						{
							currentIndex=indices[i];
							if (currentIndex >= dropIndex)
								indices[i]=currentIndex + 1;
						}
					}
				}

				collectionIterator.seek(CursorBookmark.FIRST, dropIndex);
				for (var i:int=items.length - 1; i >= 0; i--)
				{
					//insert the dropped items into the collection
					collectionIterator.insert(items[i]);
					//add the new indices for the dropped items to the selected indices
					indices.push(dropIndex + i);
				}
				this.selectedIndices=indices;
				this.dispatchEvent(new ListEvent(ListEvent.CHANGE));
			}
		}

		/**
		 * @private
		 */
		override protected function dragCompleteHandler(event:DragEvent):void
		{
			if (event.isDefaultPrevented())
				return;

			event.preventDefault();

			super.dragCompleteHandler(event);

			if (event.action == DragManager.MOVE && this.dragMoveEnabled)
			{
				if (event.relatedObject != this)
				{
					var collectionIterator:IViewCursor=this.collection.createCursor();
					collectionIterator.seek(CursorBookmark.FIRST, this.indexToDrag);
					collectionIterator.remove();
					//notify listeners that the selected items changed
					this.dispatchEvent(new ListEvent(ListEvent.CHANGE));
				}
			}
		}
		private var _selectedValues:Array;

		private var bSelectedValueSet:Boolean=false;
		
		private var bDataProviderSet:Boolean=false;

		private var _valueField:String="data";

		public function set valueField(value:String):void
		{
			_valueField=value;
		}

		override public function set dataProvider(o:Object):void
		{
			super.dataProvider=o;
			if (o != null && o.length)
			{
				bDataProviderSet=true;
			}
		}

		[Bindable("change")]
		public function get selectedValues():Array
		{
			var values:Array=[];
			for (var i:int=0; i < this.selectedItems.length; i++)
			{
				values.push(this.selectedItems[i][_valueField]);
			}
			return values;
		}

		public function set selectedValues(arr:Array):void
		{
			if (arr != null)
			{
				_selectedValues=arr;
				bSelectedValueSet=true;
				if (bSelectedValueSet && bDataProviderSet)
				{
					if (_selectedValues != null)
					{
						bSelectedValueSet=false;
						var sIndex:Array=[];
						for (var k:int=0; k < _selectedValues.length; k++)
						{
							for (var i:int=0; i < this.dataProvider.length; i++)
							{
								var item:String=this.dataProvider[i][_valueField];
								if (item == _selectedValues[k])
								{
									sIndex.push(i);
								}
							}
						}
						this.selectedIndices=sIndex;
						if (sIndex.length > 0)
						{
							this.dispatchEvent(new ListEvent(ListEvent.CHANGE))
						}
					}
				}
			}
		}
	}
}